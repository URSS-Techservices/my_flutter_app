import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:halo/features/feed/presentation/home_layout.dart';
import 'package:halo/features/feed/presentation/media_aspect_data.dart';
import 'package:halo/features/feed/presentation/post_media_chrome.dart';
import 'package:halo/services/app_video_focus.dart';
import 'package:halo/services/video_decoder_budget.dart';
import 'package:halo/services/video_dispose_serial.dart';
import 'package:halo/services/video_init_serial.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Plays only while mostly on screen. One decoder lease — never all videos at once.
/// Always autoplays/loops once visible; there is no tap-to-pause here — a tap
/// on the media opens the full post (handled by the parent), so this widget
/// owns no tap gesture of its own besides the mute button.
class PostInlineVideo extends ConsumerStatefulWidget {
  final String postId;
  final int index;
  final String videoUrl;
  /// Single-bitrate MP4 retried once if [videoUrl] (HLS) fails to init/play.
  final String fallbackUrl;
  final String thumbUrl;
  final int cacheWidth;
  final bool muted;
  final VoidCallback onMuteToggle;

  const PostInlineVideo({
    super.key,
    required this.postId,
    required this.index,
    required this.videoUrl,
    this.fallbackUrl = '',
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
  // Grace period before actually tearing down on low visibility — protects
  // against transient visibility dips from a parent layout change (e.g. the
  // aspect-ratio box resizing) instead of a real scroll-away.
  static const _teardownGrace = Duration(milliseconds: 400);
  // Delay before an eagerly-built (not-yet-visible) post actually starts
  // buffering. Hardware decoder allocation is real, measurable work on this
  // hardware (each one costs a visible Choreographer jank spike) — without
  // this delay, scrolling quickly past several video posts allocates and
  // immediately tears down a decoder for every single one of them. If a post
  // is disposed (scrolled out of range) before this fires, buffering never
  // starts for it at all.
  static const _eagerInitDelay = Duration(milliseconds: 250);

  VideoPlayerController? _ctrl;
  bool _ready = false;
  bool _error = false;
  bool _acquired = false;
  bool _aspectSent = false;
  bool _usedFallback = false;
  bool _initializing = false;
  Timer? _teardownTimer;
  Timer? _eagerInitTimer;

  /// Last-known "is this post the one actually being watched" (>=55%
  /// visible) — distinct from [_ready] (buffered). A pre-buffered post can be
  /// [_ready] well before it's ever [_activeVisible].
  bool _activeVisible = false;
  bool _hasPlayedOnce = false;

  @override
  void initState() {
    super.initState();
    AppVideoFocus.instance.addListener(_onFocus);
    // Start buffering shortly after this post is built (not immediately —
    // see _eagerInitDelay) — the SliverList's cacheExtent already builds
    // posts ~1-2 screens ahead of the visible viewport, so this naturally
    // warms upcoming videos before the user scrolls to them, bounded by
    // VideoDecoderBudget same as before. Actual playback still waits for
    // real visibility — see _onVisibility.
    _eagerInitTimer = Timer(_eagerInitDelay, () {
      _eagerInitTimer = null;
      if (!mounted) return;
      // Routed through the shared serializer: if several posts became
      // eager-eligible in the same frame, this staggers their actual
      // decoder allocations one at a time instead of letting them burst
      // together (that burst is what causes the jank, not the allocations
      // themselves happening — see VideoInitSerial's doc comment).
      unawaited(VideoInitSerial.instance.run(() => _init(awaitInitialize: true)));
    });
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
    _eagerInitTimer?.cancel();
    _teardownTimer?.cancel();
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
      _teardownTimer?.cancel();
      _teardownTimer = null;
      unawaited(_teardown());
    }
  }

  void _onVisibility(VisibilityInfo info) {
    if (!mounted || AppVideoFocus.instance.isFullscreenReel) return;
    final v = info.visibleFraction;
    _activeVisible = v >= 0.55;
    if (_activeVisible) {
      _teardownTimer?.cancel();
      _teardownTimer = null;
      if (_ctrl == null && !_error) {
        // Already actually visible — no reason to wait out the eager delay.
        _eagerInitTimer?.cancel();
        _eagerInitTimer = null;
        unawaited(_init());
      } else if (_ready && !_hasPlayedOnce) {
        // Was pre-buffered while off-screen — start playing now that it's
        // actually the one being watched, instead of waiting on _onCtrl
        // (which only fires on the initialize->ready transition).
        _startPlaybackNow();
      }
    } else if (v < 0.12) {
      if (_ctrl != null && _teardownTimer == null) {
        _teardownTimer = Timer(_teardownGrace, () {
          _teardownTimer = null;
          if (mounted) unawaited(_teardown());
        });
      }
    } else {
      // Between the two thresholds: a pending teardown is no longer clearly
      // warranted — cancel it so a brief dip doesn't kill an active video.
      _teardownTimer?.cancel();
      _teardownTimer = null;
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
    _hasPlayedOnce = false;
    if (mounted) {
      setState(() {
        _ready = false;
      });
    }
  }

  void _startPlaybackNow() {
    final c = _ctrl;
    if (c == null || !c.value.isInitialized || _hasPlayedOnce) return;
    _hasPlayedOnce = true;
    c.setVolume(widget.muted ? 0 : 1);
    c.play();
    if (mounted) setState(() {});
  }

  /// HLS (.m3u8) can't be cached this way — ExoPlayer/AVPlayer fetch each
  /// segment individually and this app-level cache only ever sees the tiny
  /// playlist text, not the actual video bytes. The flat MP4 (now primary
  /// whenever one's been processed) benefits: first view downloads it in the
  /// background while still streaming live; every view after that plays
  /// instantly from disk, no network wait at all.
  bool _isCacheableUrl(String url) => !url.toLowerCase().contains('.m3u8');

  /// [awaitInitialize] makes this wait for the actual hardware decoder
  /// allocation (`c.initialize()`) to finish before returning, instead of
  /// firing it and moving on. Only the eager pre-buffer path (queued through
  /// [VideoInitSerial]) sets this — it's what lets the serializer actually
  /// stagger allocations; the real-visibility path stays fire-and-forget so
  /// a video the user is actually looking at never waits on anything.
  Future<void> _init({bool awaitInitialize = false}) async {
    if (AppVideoFocus.instance.isFullscreenReel) return;
    if (_initializing || _ctrl != null) return;
    _initializing = true;
    try {
      final url = _usedFallback ? widget.fallbackUrl : widget.videoUrl;
      if (url.isEmpty) {
        if (!_usedFallback && widget.fallbackUrl.isNotEmpty) {
          _usedFallback = true;
          _initializing = false;
          await _init(awaitInitialize: awaitInitialize);
          return;
        }
        if (mounted) setState(() => _error = true);
        return;
      }
      if (!VideoDecoderBudget.instance.tryAcquire(_owner)) return;
      _acquired = true;

      final cacheable = _isCacheableUrl(url);
      File? cachedFile;
      if (cacheable) {
        try {
          cachedFile = (await DefaultCacheManager().getFileFromCache(url))?.file;
        } catch (_) {}
        if (!mounted) {
          _releaseAcquired();
          return;
        }
      }

      final c = cachedFile != null
          ? VideoPlayerController.file(
              cachedFile,
              videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false, allowBackgroundPlayback: false),
            )
          : VideoPlayerController.networkUrl(
              Uri.parse(url),
              videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false, allowBackgroundPlayback: false),
              httpHeaders: const {'Connection': 'keep-alive'},
            );
      _ctrl = c;
      c.addListener(_onCtrl);
      final initFuture = c.initialize().catchError((_) {
        _releaseAcquired();
        _handleFailure();
      });
      if (awaitInitialize) {
        await initFuture;
      } else {
        unawaited(initFuture);
      }

      if (cacheable && cachedFile == null) {
        unawaited(() async {
          try {
            await DefaultCacheManager().downloadFile(url);
          } catch (_) {}
        }());
      }
    } catch (_) {
      _releaseAcquired();
      _handleFailure();
    } finally {
      _initializing = false;
    }
  }

  void _releaseAcquired() {
    if (_acquired) {
      VideoDecoderBudget.instance.release(_owner);
      _acquired = false;
    }
  }

  /// On the first failure, retry once with [PostInlineVideo.fallbackUrl]
  /// (single-bitrate MP4) before giving up and showing the error icon.
  void _handleFailure() {
    if (!mounted) return;
    final c = _ctrl;
    _ctrl = null;
    c?.removeListener(_onCtrl);
    unawaited(c?.dispose().catchError((_) {}));

    if (!_usedFallback &&
        widget.fallbackUrl.isNotEmpty &&
        widget.fallbackUrl != widget.videoUrl) {
      _usedFallback = true;
      unawaited(_init());
      return;
    }
    setState(() => _error = true);
  }

  void _onCtrl() {
    if (!mounted) return;
    final c = _ctrl;
    if (c == null) return;
    if (!_ready && c.value.isInitialized) {
      c.setLooping(true);
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
      // Only start playing now if this post is actually the one being
      // watched — otherwise it was pre-buffered ahead of time and should
      // stay paused (silent, first frame) until _onVisibility says it's active.
      if (_activeVisible) _startPlaybackNow();
    }
    if (c.value.hasError && !_error) {
      _releaseAcquired();
      _handleFailure();
    }
  }

  @override
  Widget build(BuildContext context) {
    final thumb = widget.thumbUrl;
    // Gated on _hasPlayedOnce (not just _ready) so a pre-buffered-but-not-yet
    // -watched post keeps showing its thumbnail instead of a frozen video frame.
    final playing = _ready && _hasPlayedOnce && _ctrl != null && _ctrl!.value.isInitialized;
    return VisibilityDetector(
      key: Key('home_inline_${widget.postId}_${widget.videoUrl.hashCode}'),
      onVisibilityChanged: _onVisibility,
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
    );
  }
}
