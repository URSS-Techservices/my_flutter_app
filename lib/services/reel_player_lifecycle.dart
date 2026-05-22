import 'dart:io';

import 'package:flutter/foundation.dart';

/// Phase 4 — platform-specific reel / feed player limits and lifecycle logging.
class ReelPlatformPolicy {
  ReelPlatformPolicy._();

  static bool get isIOS => !kIsWeb && Platform.isIOS;

  static bool get isAndroid => !kIsWeb && Platform.isAndroid;

  /// Max simultaneous pooled players (warm + active).
  static int get maxPoolSlots => isIOS ? 2 : 3;

  /// Reel indices to keep warm relative to [centerIndex].
  static Iterable<int> warmIndices(int centerIndex, int length) sync* {
    if (length <= 0) return;
    if (isIOS) {
      for (final i in [centerIndex, centerIndex + 1]) {
        if (i >= 0 && i < length) yield i;
      }
      return;
    }
    for (final i in [centerIndex - 1, centerIndex, centerIndex + 1, centerIndex + 2]) {
      if (i >= 0 && i < length) yield i;
    }
  }

  /// Extra scroll-ahead index while swiping (Android only).
  static int? scrollAheadIndex(double page, int length) {
    if (isIOS || length <= 0) return null;
    final center = page.round().clamp(0, length - 1);
    final ahead = page.ceil().clamp(0, length - 1);
    return ahead != center ? ahead : null;
  }

  static bool get useAheadWarmSurfaces => !isIOS;

  /// iOS: data-source prepare only — no muted play on hidden surfaces.
  static bool get allowMutedWarmPlay => !isIOS;
}

/// Debug lifecycle lines for reel stress testing.
class ReelLifecycleLog {
  static void bind(String reelId, {int? generation, String? url}) {
    debugPrint(
      '[ReelLifecycle] bind reel=$reelId gen=$generation url=${_short(url)}',
    );
  }

  static void unbind(String reelId, {int? generation}) {
    debugPrint('[ReelLifecycle] unbind reel=$reelId gen=$generation');
  }

  static void dispose(String reelId, {int? generation, String reason = ''}) {
    debugPrint(
      '[ReelLifecycle] dispose reel=$reelId gen=$generation'
      '${reason.isEmpty ? '' : ' reason=$reason'}',
    );
  }

  static void activate(String reelId) {
    debugPrint('[ReelLifecycle] activate reel=$reelId');
  }

  static void deactivate(String reelId) {
    debugPrint('[ReelLifecycle] deactivate reel=$reelId');
  }

  static void generationMismatch(String reelId, {int? expected, int? actual}) {
    debugPrint(
      '[ReelLifecycle] generation mismatch reel=$reelId'
      ' expected=$expected actual=$actual — abort',
    );
  }

  static void fallbackStart(String reelId, String url) {
    debugPrint(
      '[ReelLifecycle] fallback start reel=$reelId url=${_short(url)}',
    );
  }

  static void fallbackSuccess(String reelId, String url) {
    debugPrint(
      '[ReelLifecycle] fallback success reel=$reelId url=${_short(url)}',
    );
  }

  static void playerException(String reelId, Object? detail) {
    debugPrint('[ReelLifecycle] player exception reel=$reelId detail=$detail');
  }

  static void firstFrameRendered(String reelId) {
    debugPrint('[ReelLifecycle] first frame rendered reel=$reelId');
  }

  static void memoryPressure({String? keepReelId}) {
    debugPrint(
      '[ReelLifecycle] memory pressure'
      '${keepReelId == null ? '' : ' keep=$keepReelId'}',
    );
  }

  static String _short(String? url) {
    if (url == null || url.isEmpty) return '';
    final u = url;
    return u.length <= 72 ? u : '${u.substring(0, 72)}…';
  }
}

/// Tracks URLs already attempted to prevent HLS ↔ MP4 loops.
class ReelPlaybackFallbackTracker {
  final Set<String> _attempted = {};

  bool hasAttempted(String url) =>
      url.isNotEmpty && _attempted.contains(url);

  void markAttempted(String url) {
    if (url.isNotEmpty) _attempted.add(url);
  }

  void reset() => _attempted.clear();

  /// Next URL to try, or null if exhausted (single fallback pass).
  String? pickNext({
    required String primaryUrl,
    required String fallbackUrl,
    String? rawUrl,
  }) {
    final ordered = <String>[
      primaryUrl,
      fallbackUrl,
      if (rawUrl != null && rawUrl.isNotEmpty) rawUrl,
    ];
    for (final url in ordered) {
      if (url.isEmpty || hasAttempted(url)) continue;
      return url;
    }
    return null;
  }
}

/// Per-widget bind generation (increments on dispose / rebind).
class ReelBindGeneration {
  int _value = 0;

  int get value => _value;

  int bump() => ++_value;

  bool matches(int token) => token == _value;
}
