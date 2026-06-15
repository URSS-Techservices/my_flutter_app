import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class VideoQuickEditResult {
  final File file;
  final Uint8List? coverBytes;
  final int trimStartMs;
  final int trimEndMs;

  const VideoQuickEditResult({
    required this.file,
    required this.coverBytes,
    required this.trimStartMs,
    required this.trimEndMs,
  });
}

class VideoQuickEditPage extends StatefulWidget {
  final File file;
  const VideoQuickEditPage({super.key, required this.file});

  @override
  State<VideoQuickEditPage> createState() => _VideoQuickEditPageState();
}

class _VideoQuickEditPageState extends State<VideoQuickEditPage> {
  VideoPlayerController? _ctrl;
  Timer? _ticker;
  bool _ready = false;
  bool _saving = false;

  double _trimStartMs = 0;
  double _trimEndMs = 0;
  double _coverMs = 0;
  double _positionMs = 0;
  double _durationMs = 1;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final ctrl = VideoPlayerController.file(widget.file);
      await ctrl.initialize();
      _ctrl = ctrl;
      final d = ctrl.value.duration.inMilliseconds.toDouble();
      _durationMs = d < 1 ? 1 : d;
      _trimStartMs = 0;
      _trimEndMs = d;
      _coverMs = 0;
      _positionMs = 0;
      _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
        final c = _ctrl;
        if (!mounted || c == null || !c.value.isInitialized) return;
        final p = c.value.position.inMilliseconds.toDouble();
        if (p >= _trimEndMs) {
          c.pause();
          c.seekTo(Duration(milliseconds: _trimStartMs.toInt()));
          setState(() => _positionMs = _trimStartMs);
        } else {
          setState(() => _positionMs = p);
        }
      });
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _ctrl?.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    final c = _ctrl;
    if (c == null || !_ready) return;
    if (c.value.isPlaying) {
      await c.pause();
    } else {
      if (_positionMs < _trimStartMs || _positionMs > _trimEndMs) {
        await c.seekTo(Duration(milliseconds: _trimStartMs.toInt()));
      }
      await c.play();
    }
    if (mounted) setState(() {});
  }

  Future<void> _done() async {
    if (_saving) return;
    setState(() => _saving = true);
    Uint8List? coverBytes;
    try {
      coverBytes = await VideoThumbnail.thumbnailData(
        video: widget.file.path,
        imageFormat: ImageFormat.JPEG,
        timeMs: _coverMs.toInt(),
        maxWidth: 720,
        quality: 80,
      );
    } catch (_) {
      coverBytes = null;
    }
    if (!mounted) return;
    Navigator.pop(
      context,
      VideoQuickEditResult(
        file: widget.file,
        coverBytes: coverBytes,
        trimStartMs: _trimStartMs.toInt(),
        trimEndMs: _trimEndMs.toInt(),
      ),
    );
  }

  String _fmtMs(double ms) {
    final s = (ms / 1000).floor();
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final r = (s % 60).toString().padLeft(2, '0');
    return '$m:$r';
  }

  @override
  Widget build(BuildContext context) {
    final c = _ctrl;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Edit Video'),
        actions: [
          TextButton(
            onPressed: _ready && !_saving ? _done : null,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Done', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: !_ready || c == null || !c.value.isInitialized
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _togglePlay,
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: c.value.aspectRatio,
                          child: VideoPlayer(c),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(_fmtMs(_positionMs), style: const TextStyle(color: Colors.white70)),
                      const Spacer(),
                      Text('${_fmtMs(_trimStartMs)} - ${_fmtMs(_trimEndMs)}',
                          style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                  RangeSlider(
                    values: RangeValues(_trimStartMs, _trimEndMs),
                    min: 0,
                    max: _durationMs,
                    divisions: _durationMs > 1000 ? (_durationMs / 1000).floor() : null,
                    labels: RangeLabels(_fmtMs(_trimStartMs), _fmtMs(_trimEndMs)),
                    onChanged: (v) {
                      final minGap = 1000.0;
                      final start = v.start;
                      var end = v.end;
                      if (end - start < minGap) end = (start + minGap).clamp(0, _durationMs);
                      setState(() {
                        _trimStartMs = start;
                        _trimEndMs = end;
                        if (_coverMs < _trimStartMs) _coverMs = _trimStartMs;
                        if (_coverMs > _trimEndMs) _coverMs = _trimEndMs;
                      });
                    },
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Cover frame: ${_fmtMs(_coverMs)}',
                        style: const TextStyle(color: Colors.white70)),
                  ),
                  Slider(
                    value: _coverMs.clamp(_trimStartMs, _trimEndMs),
                    min: _trimStartMs,
                    max: _trimEndMs > _trimStartMs ? _trimEndMs : _trimStartMs + 1,
                    onChanged: (v) => setState(() => _coverMs = v),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
    );
  }
}
