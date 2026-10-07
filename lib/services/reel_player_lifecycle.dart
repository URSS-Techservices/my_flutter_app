import 'dart:io';



import 'package:flutter/foundation.dart';



import 'app_logger.dart';
import 'reel_preload_policy.dart';



class _LifecycleLogThrottle {

  static final Map<String, DateTime> _last = {};



  static bool shouldLog(String key,

      {Duration interval = const Duration(seconds: 15)}) {

    final now = DateTime.now();

    final prev = _last[key];

    if (prev != null && now.difference(prev) < interval) return false;

    _last[key] = now;

    return true;

  }

}



/// Phase 4 — platform-specific reel / feed player limits and lifecycle logging.

class ReelPlatformPolicy {

  ReelPlatformPolicy._();



  static bool get isIOS => !kIsWeb && Platform.isIOS;



  static bool get isAndroid => !kIsWeb && Platform.isAndroid;



  /// Hard cap: **2 simultaneous ExoPlayer / AVPlayer** instances (current + next).

  /// Anything above is LRU-evicted by [ReelPlaybackPool] to prevent

  /// `pipelineFull: too many frames in pipeline` and 256 MB heap OOM.

  /// 3 slots: current + next 2. The pool is LRU so the oldest is evicted
  /// when a 4th would be added. 3 is safe on modern iOS/Android (≥3 GB RAM).
  static int get maxPoolSlots => isAndroid ? 4 : 5;



  /// Warm window: 1 back + 3 ahead (see [ReelPreloadPolicy]).
  static Iterable<int> warmIndices(int centerIndex, int length) sync* {
    if (length <= 0) return;
    for (final i in ReelPreloadPolicy.warmIndices(centerIndex, length)) {
      yield i;
    }
  }



  /// We no longer pre-render an extra scroll-ahead surface — Instagram doesn't.

  static int? scrollAheadIndex(double page, int length) => null;



  static bool get useAheadWarmSurfaces => false;



  /// Never play muted on a hidden surface — that's where OOM comes from.

  static bool get allowMutedWarmPlay => false;

}



/// Debug lifecycle lines for reel stress testing.

class ReelLifecycleLog {

  static void bind(String reelId, {int? generation, String? url}) {

    AppLogger.debug(

      LogCategory.lifecycle,

      'bind reel=$reelId gen=$generation url=${_short(url)}',

    );

  }



  static void unbind(String reelId, {int? generation}) {

    AppLogger.debug(

      LogCategory.lifecycle,

      'unbind reel=$reelId gen=$generation',

    );

  }



  static void dispose(String reelId, {int? generation, String reason = ''}) {

    AppLogger.debug(

      LogCategory.lifecycle,

      'dispose reel=$reelId gen=$generation'

      '${reason.isEmpty ? '' : ' reason=$reason'}',

    );

  }



  static void activate(String reelId) {

    AppLogger.debug(LogCategory.lifecycle, 'activate reel=$reelId');

  }



  static void deactivate(String reelId) {

    AppLogger.debug(LogCategory.lifecycle, 'deactivate reel=$reelId');

  }



  static void generationMismatch(String reelId, {int? expected, int? actual}) {

    if (!_LifecycleLogThrottle.shouldLog('gen_mismatch:$reelId')) return;

    AppLogger.debug(

      LogCategory.lifecycle,

      'generation mismatch reel=$reelId expected=$expected actual=$actual — abort',

    );

  }



  static void fallbackStart(String reelId, String url) {

    AppLogger.debug(

      LogCategory.lifecycle,

      'fallback start reel=$reelId url=${_short(url)}',

    );

  }



  static void fallbackSuccess(String reelId, String url) {

    AppLogger.debug(

      LogCategory.lifecycle,

      'fallback success reel=$reelId url=${_short(url)}',

    );

  }



  static void playerException(String reelId, Object? detail) {

    AppLogger.warning(

      LogCategory.lifecycle,

      'player exception reel=$reelId detail=$detail',

    );

  }



  static void firstFrameRendered(String reelId) {

    AppLogger.perf('first_frame', fields: {'surface': 'lifecycle', 'id': reelId});

  }



  static void memoryPressure({String? keepReelId}) {

    AppLogger.warning(

      LogCategory.memory,

      'memory pressure${keepReelId == null ? '' : ' keep=$keepReelId'}',

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


