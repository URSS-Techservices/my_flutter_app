import 'dart:async';

import 'package:video_player/video_player.dart';

import 'package:halo/services/video_decoder_budget.dart';

/// Starts loading the tapped Explore reel before the viewer route opens.
class ExploreReelPrefetch {
  ExploreReelPrefetch._();
  static final ExploreReelPrefetch instance = ExploreReelPrefetch._();

  VideoPlayerController? _ctrl;
  String? _postId;
  String? _owner;

  bool get hasController => _ctrl != null;

  /// Call on grid [onTapDown] for video cells.
  void start({
    required String postId,
    required String videoUrl,
    String fallbackUrl = '',
  }) {
    final url = videoUrl.trim();
    if (url.isEmpty) return;
    if (_postId == postId && _ctrl != null) return;

    unawaited(cancel());

    final owner = 'explore_reel:$postId';
    if (!VideoDecoderBudget.instance.tryAcquire(owner)) return;

    _postId = postId;
    _owner = owner;
    final c = VideoPlayerController.networkUrl(
      Uri.parse(url),
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: false,
        allowBackgroundPlayback: false,
      ),
      httpHeaders: const {'Connection': 'keep-alive'},
    );
    _ctrl = c;

    unawaited(_initialize(
      c,
      owner,
      primaryUrl: url,
      fallbackUrl: fallbackUrl,
    ));
  }

  Future<void> _initialize(
    VideoPlayerController c,
    String owner, {
    required String primaryUrl,
    required String fallbackUrl,
  }) async {
    try {
      await c.initialize();
      await c.setLooping(true);
      await c.setVolume(0.0);
    } catch (_) {
      final alt = fallbackUrl.trim();
      if (alt.isNotEmpty && alt != primaryUrl) {
        try {
          await c.dispose();
        } catch (_) {}
        final c2 = VideoPlayerController.networkUrl(
          Uri.parse(alt),
          videoPlayerOptions: VideoPlayerOptions(
            mixWithOthers: false,
            allowBackgroundPlayback: false,
          ),
          httpHeaders: const {'Connection': 'keep-alive'},
        );
        _ctrl = c2;
        try {
          await c2.initialize();
          await c2.setLooping(true);
          await c2.setVolume(0.0);
          return;
        } catch (_) {
          try {
            await c2.dispose();
          } catch (_) {}
        }
      }
      await cancel();
    }
  }

  /// Hand off to [_ReelViewer]; returns null if ids do not match.
  VideoPlayerController? take(String postId) {
    if (_postId != postId || _ctrl == null) return null;
    final c = _ctrl;
    _ctrl = null;
    _postId = null;
    _owner = null;
    return c;
  }

  String? ownerFor(String postId) {
    if (_postId != postId) return null;
    return _owner;
  }

  Future<void> cancel() async {
    final c = _ctrl;
    final owner = _owner;
    _ctrl = null;
    _postId = null;
    _owner = null;
    if (c != null) {
      try {
        await c.dispose();
      } catch (_) {}
    }
    if (owner != null) {
      VideoDecoderBudget.instance.releaseAll(owner);
    }
  }
}
