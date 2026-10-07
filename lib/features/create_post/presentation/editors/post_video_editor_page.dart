import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import 'package:halo/features/create_post/domain/media_quality_profile.dart';

/// Outcome of [PostVideoEditorPage].
///
/// When the user only trimmed (no visual edits, audio untouched) the original
/// file is returned with [trimStart]/[trimEnd] so the trim is applied by the
/// upload pipeline without a costly local re-encode. Any visual edit or mute
/// renders a new file with everything (including the trim) baked in, and the
/// trim fields are null.
class PostVideoEditResult {
  final File file;
  final Uint8List? coverBytes;
  final Duration? trimStart;
  final Duration? trimEnd;

  const PostVideoEditResult({
    required this.file,
    required this.coverBytes,
    this.trimStart,
    this.trimEnd,
  });
}

/// Full video editor shown right after a video is picked or recorded: trim,
/// mute, crop / rotate / flip, filters, tune (brightness, contrast,
/// saturation, …), blur, freehand paint, text and emoji overlays.
///
/// Pops with a [PostVideoEditResult], or `null` when the user closes the
/// editor without pressing Done.
class PostVideoEditorPage extends StatefulWidget {
  final File file;

  const PostVideoEditorPage({super.key, required this.file});

  @override
  State<PostVideoEditorPage> createState() => _PostVideoEditorPageState();
}

class _PostVideoEditorPageState extends State<PostVideoEditorPage> {
  static const int _thumbnailCount = 10;

  final String _taskId = DateTime.now().microsecondsSinceEpoch.toString();

  late final EditorVideo _video = EditorVideo.file(widget.file);
  VideoPlayerController? _player;
  ProVideoController? _proController;
  VideoMetadata? _metadata;
  List<ImageProvider>? _thumbnails;

  TrimDurationSpan? _durationSpan;
  TrimDurationSpan? _pendingSpan;
  bool _isSeeking = false;

  PostVideoEditResult? _result;

  late final ProImageEditorConfigs _configs = ProImageEditorConfigs(
    dialogConfigs: DialogConfigs(
      widgets: DialogWidgets(
        loadingDialog: (message, configs) => _RenderProgressDialog(taskId: _taskId),
      ),
    ),
    mainEditor: MainEditorConfigs(
      tools: const [
        SubEditorMode.paint,
        SubEditorMode.text,
        SubEditorMode.cropRotate,
        SubEditorMode.tune,
        SubEditorMode.filter,
        SubEditorMode.blur,
        SubEditorMode.emoji,
      ],
      widgets: MainEditorWidgets(
        removeLayerArea: (removeAreaKey, editor, rebuildStream, isLayerBeingTransformed) =>
            VideoEditorRemoveArea(
          removeAreaKey: removeAreaKey,
          editor: editor,
          rebuildStream: rebuildStream,
          isLayerBeingTransformed: isLayerBeingTransformed,
        ),
      ),
    ),
    paintEditor: const PaintEditorConfigs(
      // Pixelate / blur brushes can't be rendered onto video frames.
      tools: [
        PaintMode.freeStyle,
        PaintMode.arrow,
        PaintMode.line,
        PaintMode.rect,
        PaintMode.circle,
        PaintMode.dashLine,
        PaintMode.polygon,
        PaintMode.eraser,
      ],
    ),
    videoEditor: VideoEditorConfigs(
      initialPlay: false,
      initialMuted: false,
      isAudioSupported: true,
      enablePlayButton: true,
      minTrimDuration: const Duration(seconds: 1),
      maxTrimDuration: MediaQualityThresholds.maxVideoDuration,
      playTimeSmoothingDuration: const Duration(milliseconds: 600),
    ),
  );

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _player?.removeListener(_onPositionChanged);
    _player?.dispose();
    _proController?.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      final player = VideoPlayerController.file(widget.file);
      _player = player;
      _generateThumbnails();
      final results = await Future.wait([
        ProVideoEditor.instance.getMetadata(_video),
        player.initialize(),
      ]);
      await player.setLooping(false);
      if (!mounted) return;

      final metadata = results.first as VideoMetadata;
      _metadata = metadata;
      _proController = ProVideoController(
        videoPlayer: Center(
          child: AspectRatio(
            aspectRatio: player.value.aspectRatio,
            child: VideoPlayer(player),
          ),
        ),
        initialResolution: metadata.resolution,
        videoDuration: metadata.duration,
        fileSize: metadata.fileSize,
        bitrate: metadata.bitrate,
        thumbnails: _thumbnails,
      );
      player.addListener(_onPositionChanged);
      setState(() {});
    } catch (_) {
      if (mounted) Navigator.pop(context);
    }
  }

  void _generateThumbnails() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        final width = MediaQuery.sizeOf(context).width / _thumbnailCount * MediaQuery.devicePixelRatioOf(context);
        final frames = await ProVideoEditor.instance.getKeyFrames(
          KeyFramesConfigs(
            video: _video,
            outputSize: Size.square(width),
            boxFit: ThumbnailBoxFit.cover,
            maxOutputFrames: _thumbnailCount,
            outputFormat: ThumbnailFormat.jpeg,
          ),
        );
        if (!mounted) return;
        final thumbnails = frames.map<ImageProvider>(MemoryImage.new).toList();
        await Future.wait(thumbnails.map((t) => precacheImage(t, context)));
        _thumbnails = thumbnails;
        _proController?.thumbnails = thumbnails;
      } catch (_) {
        // The trim bar works without thumbnails.
      }
    });
  }

  void _onPositionChanged() {
    final player = _player;
    final controller = _proController;
    final metadata = _metadata;
    if (player == null || controller == null || metadata == null) return;

    final position = player.value.position;
    controller.setPlayTime(position);

    final span = _durationSpan;
    if (span != null && position >= span.end) {
      _seekTo(span);
    } else if (position >= metadata.duration) {
      _seekTo(TrimDurationSpan(start: Duration.zero, end: metadata.duration));
    }
  }

  Future<void> _seekTo(TrimDurationSpan span) async {
    _durationSpan = span;
    if (_isSeeking) {
      _pendingSpan = span;
      return;
    }
    _isSeeking = true;
    _proController?.pause();
    _proController?.setPlayTime(span.start);
    await _player?.pause();
    await _player?.seekTo(span.start);
    _isSeeking = false;

    final next = _pendingSpan;
    if (next != null) {
      _pendingSpan = null;
      await _seekTo(next);
    }
  }

  bool _hasVisualEdits(CompleteParameters p) {
    return p.layers.isNotEmpty ||
        p.isTransformed ||
        p.blur > 0 ||
        p.matrixFilterList.isNotEmpty ||
        p.matrixTuneAdjustmentsList.isNotEmpty;
  }

  Future<void> _onComplete(CompleteParameters parameters) async {
    final audioEnabled = _proController?.isAudioEnabled ?? true;
    await _player?.pause();

    if (!_hasVisualEdits(parameters) && audioEnabled) {
      final start = parameters.startTime;
      _result = PostVideoEditResult(
        file: widget.file,
        coverBytes: await _cover(widget.file, start ?? Duration.zero),
        trimStart: start,
        trimEnd: parameters.endTime,
      );
      return;
    }

    final directory = await getTemporaryDirectory();
    final renderData = VideoRenderData(
      id: _taskId,
      videoSegments: [VideoSegment(video: _video)],
      imageLayers: [
        if (parameters.layers.isNotEmpty) ImageLayer(image: EditorLayerImage.memory(parameters.image)),
      ],
      blur: parameters.blur,
      colorFilters: [ColorFilter(matrix: parameters.colorFiltersCombined)],
      startTime: parameters.startTime,
      endTime: parameters.endTime,
      transform: parameters.isTransformed
          ? ExportTransform(
              width: parameters.cropWidth,
              height: parameters.cropHeight,
              rotateTurns: 4 - parameters.rotateTurns,
              x: parameters.cropX,
              y: parameters.cropY,
              flipX: parameters.flipX,
              flipY: parameters.flipY,
            )
          : null,
      enableAudio: audioEnabled,
      outputFormat: VideoOutputFormat.mp4,
      bitrate: _metadata?.bitrate,
      shouldOptimizeForNetworkUse: true,
    );

    try {
      final path = await ProVideoEditor.instance.renderVideoToFile(
        '${directory.path}/halo_edit_${DateTime.now().microsecondsSinceEpoch}.mp4',
        renderData,
      );
      final output = File(path);
      _result = PostVideoEditResult(file: output, coverBytes: await _cover(output, Duration.zero));
    } catch (_) {
      _result = null;
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text('Could not apply the video edits. Please try again.')),
        );
      }
    }
  }

  Future<Uint8List?> _cover(File file, Duration at) async {
    try {
      return await VideoThumbnail.thumbnailData(
        video: file.path,
        imageFormat: ImageFormat.JPEG,
        timeMs: at.inMilliseconds,
        maxWidth: 720,
        quality: 80,
      );
    } catch (_) {
      return null;
    }
  }

  void _onCloseEditor(EditorMode editorMode) {
    if (editorMode != EditorMode.main) {
      Navigator.pop(context);
      return;
    }
    _player?.pause();
    Navigator.pop(context, _result);
  }

  @override
  Widget build(BuildContext context) {
    final controller = _proController;
    final player = _player;
    if (controller == null || player == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return ProImageEditor.video(
      controller,
      configs: _configs,
      callbacks: ProImageEditorCallbacks(
        onCompleteWithParameters: _onComplete,
        onCloseEditor: _onCloseEditor,
        videoEditorCallbacks: VideoEditorCallbacks(
          onPause: player.pause,
          onPlay: player.play,
          onMuteToggle: (isMuted) => player.setVolume(isMuted ? 0 : 1),
          onTrimSpanUpdate: (_) {
            if (player.value.isPlaying) controller.pause();
          },
          onTrimSpanEnd: _seekTo,
        ),
      ),
    );
  }
}

class _RenderProgressDialog extends StatelessWidget {
  final String taskId;

  const _RenderProgressDialog({required this.taskId});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const ModalBarrier(color: Colors.black54, dismissible: false),
        Center(
          child: AlertDialog(
            content: StreamBuilder<ProgressModel>(
              stream: ProVideoEditor.instance.progressStreamById(taskId),
              builder: (context, snapshot) {
                final progress = snapshot.data?.progress ?? 0;
                return Row(
                  children: [
                    CircularProgressIndicator(value: progress > 0 ? progress : null),
                    const SizedBox(width: 16),
                    Expanded(child: Text('Applying edits… ${(progress * 100).round()}%')),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
