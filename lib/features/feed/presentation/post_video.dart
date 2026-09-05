import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:halo/features/feed/presentation/home_layout.dart';
import 'package:halo/features/feed/presentation/media_aspect_data.dart';
import 'package:halo/features/feed/presentation/post_media_chrome.dart';
import 'package:halo/services/app_video_focus.dart';
import 'package:halo/services/video_decoder_budget.dart';
import 'package:halo/services/video_dispose_serial.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Plays only while mostly on screen. One decoder lease — never all videos at once.
class PostInlineVideo extends ConsumerStatefulWidget {
  final String postId;
  final int index;
  final String videoUrl;
  final String thumbUrl;
  final int cacheWidth;
  final bool muted;
  final VoidCallback onMuteToggle;

  const PostInlineVideo({
    super.key,
    required this.postId,
    required this.index,
    required this.videoUrl,
    required this.thumbUrl,
    required this.cacheWidth,
    required this.muted,
    required this.onMuteToggle,
  });

  @override
  ConsumerState<PostInlineVideo> createState() => _PostInlineVideoState();
}

class _PostInlineVideoState extends ConsumerState<PostInlineVideo> {
  static const _owner = 'home_inline';
  VideoPlayerController? _ctrl;
  bool _ready = false;
  bool _error = false;
  bool _acquired = false;
  bool _aspectSent = false;

  @override
  void initState() {
    super.initState();
    AppVideoFocus.instance.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(covariant PostInlineVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.muted != widget.muted) {
      _ctrl?.setVolume(widget.muted ? 0 : 1);
    }
  }

  @override
  void dispose() {
    AppVideoFocus.instance.removeListener(_onFocus);
    final c = _ctrl;
    _ctrl = null;
    c?.removeListener(_onCtrl);
    try {
      c?.pause();
      c?.dispose();
    } catch (_) {}
    if (_acquired) {
      VideoDecoderBudget.instance.release(_owner);
      _acquired = false;
    }
    super.dispose();
  }

  void _onFocus() {
    if (!mounted) return;
    if (AppVideoFocus.instance.isFullscreenReel) {
      unawaited(_teardown());
    }
  }

  void _onVisibility(VisibilityInfo info) {
    if (!mounted || AppVideoFocus.instance.isFullscreenReel) return;
    final v = info.visibleFraction;
    if (v >= 0.55 && _ctrl == null && !_error) {
      _init();
    } else if (v < 0.12 && _ctrl != null) {
      unawaited(_teardown());
    }
  }

  Future<void> _teardown() async {
    final c = _ctrl;
    _ctrl = null;
    if (c != null) {
      c.removeListener(_onCtrl);
      await VideoDisposeSerial.instance.run(() async {
        try {
          c.pause();
          await c.dispose();
        } catch (_) {}
      });
    }
    if (_acquired) {
      VideoDecoderBudget.instance.release(_owner);
      _acquired = false;
    }
    if (mounted) {
      setState(() {
        _ready = false;
      });
    }
  }

  void _init() {
    if (AppVideoFocus.instance.isFullscreenReel) return;
    if (widget.videoUrl.isEmpty) {
      setState(() => _error = true);
      return;
    }
    if (!VideoDecoderBudget.instance.tryAcquire(_owner)) return;
    _acquired = true;
    try {
      final c = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: false,
          allowBackgroundPlayback: false,
        ),
        httpHeaders: const {'Connection': 'keep-alive'},
      );
      _ctrl = c;
      c.addListener(_onCtrl);
      c.initialize().catchError((_) {
        if (_acquired) {
          VideoDecoderBudget.instance.release(_owner);
          _acquired = false;
        }
        if (mounted) setState(() => _error = true);
      });
    } catch (_) {
      if (_acquired) {
        VideoDecoderBudget.instance.release(_owner);
        _acquired = false;
      }
      if (mounted) setState(() => _error = true);
    }
  }

  void _onCtrl() {
    if (!mounted) return;
    final c = _ctrl;
    if (c == null) return;
    if (!_ready && c.value.isInitialized) {
      c.setLooping(true);
      c.setVolume(widget.muted ? 0 : 1);
      c.play();
      final size = c.value.size;
      if (!_aspectSent && size.height > 0) {
        _aspectSent = true;
        reportMediaAspect(
          ref,
          isMounted: () => mounted,
          postId: widget.postId,
          index: widget.index,
          aspect: size.width / size.height,
        );
      }
      setState(() => _ready = true);
    }
    if (c.value.hasError && !_error) setState(() => _error = true);
  }

  void _toggle() {
    final c = _ctrl;
    if (c == null || !c.value.isInitialized) return;
    setState(() {
      c.value.isPlaying ? c.pause() : c.play();
    });
  }

  @override
  Widget build(BuildContext context) {
    final thumb = widget.thumbUrl;
    final playing = _ready && _ctrl != null && _ctrl!.value.isInitialized;
    return VisibilityDetector(
      key: Key('home_inline_${widget.postId}_${widget.videoUrl.hashCode}'),
      onVisibilityChanged: _onVisibility,
      child: GestureDetector(
        onTap: _toggle,
        child: ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (thumb.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: thumb,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  memCacheWidth: widget.cacheWidth,
                  placeholder: (_, __) =>
                      const ColoredBox(color: HomeLayout.mediaFill),
                  errorWidget: (_, __, ___) =>
                      const ColoredBox(color: HomeLayout.mediaFill),
                )
              else
                const ColoredBox(color: HomeLayout.mediaFill),
              if (playing)
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _ctrl!.value.size.width,
                    height: _ctrl!.value.size.height,
                    child: VideoPlayer(_ctrl!),
                  ),
                ),
              if (!playing)
                const Center(
                  child: Icon(
                    Icons.play_circle_fill_rounded,
                    color: Colors.white70,
                    size: 56,
                  ),
                ),
              if (_error)
                const Center(
                  child: Icon(
                    Icons.videocam_off_outlined,
                    color: Colors.white54,
                    size: 36,
                  ),
                ),
              Positioned(
                right: 10,
                bottom: 10,
                child: MediaMuteButton(
                  muted: widget.muted,
                  onTap: widget.onMuteToggle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
