import 'package:flutter/foundation.dart';

import 'app_logger.dart';

/// Single place to control console noise and perf file capture.
///
/// Edit values here, hot-restart the app (`R` in `flutter run`), then reproduce
/// the slow path (Explore scroll, open reels, swipe).
class LoggingConfig {
  LoggingConfig._();

  /// Master switch — when false, almost nothing prints (errors still can).
  static bool enabled = true;

  /// Minimum level printed to the console. Typical presets:
  ///   - [LogLevel.error]   → only failures
  ///   - [LogLevel.warning] → failures + memory/decoder warnings
  ///   - [LogLevel.info]    → + perf / metrics / Firestore timing
  ///   - [LogLevel.debug]   → + lifecycle, pool, prefetch (very chatty)
  static LogLevel minConsoleLevel = LogLevel.info;

  /// When non-empty, only these categories print (still respects [minConsoleLevel]).
  /// When empty, all categories are allowed.
  static Set<LogCategory> categories = {
    LogCategory.perf,
    LogCategory.metric,
    LogCategory.explore,
    LogCategory.reel,
    LogCategory.memory,
    LogCategory.error,
    LogCategory.warning,
  };

  /// Append [LogCategory.perf] and [LogCategory.metric] lines to a session file.
  static bool writePerfToFile = true;

  /// Max lines kept in memory before oldest perf lines drop (export uses buffer + file).
  static int perfBufferMaxLines = 800;

  /// Quiet defaults for everyday dev (errors + warnings only).
  static void applyQuietDefaults() {
    enabled = true;
    minConsoleLevel = LogLevel.warning;
    categories = {};
    writePerfToFile = false;
  }

  /// Recommended while profiling Explore + Reels (profile mode).
  static void applyProfilePerfDefaults() {
    enabled = true;
    minConsoleLevel = LogLevel.info;
    categories = {
      LogCategory.perf,
      LogCategory.metric,
      LogCategory.explore,
      LogCategory.reel,
      LogCategory.memory,
      LogCategory.pool,
      LogCategory.warning,
      LogCategory.error,
    };
    writePerfToFile = true;
  }

  /// Full firehose — only when debugging pool/lifecycle spam.
  static void applyVerboseDefaults() {
    enabled = true;
    minConsoleLevel = LogLevel.debug;
    categories = {};
    writePerfToFile = true;
  }

  static void applyForCurrentMode() {
    if (kProfileMode) {
      applyProfilePerfDefaults();
    } else if (kDebugMode) {
      applyQuietDefaults();
    } else {
      enabled = false;
      writePerfToFile = false;
    }
  }
}
