import 'dart:async';

import 'package:flutter/foundation.dart';

import 'logging_config.dart';
import 'perf_session_log.dart';

/// Severity for console filtering.
enum LogLevel {
  error(0, 'ERROR'),
  warning(1, 'WARN'),
  info(2, 'INFO'),
  debug(3, 'DEBUG');

  const LogLevel(this.priority, this.label);
  final int priority;
  final String label;
}

/// Logical channel — toggle via [LoggingConfig.categories].
enum LogCategory {
  error,
  warning,
  perf,
  metric,
  explore,
  reel,
  pool,
  lifecycle,
  memory,
  firebase,
  resolver,
  general,
}

class AppLogger {
  AppLogger._();

  static final Map<String, DateTime> _throttle = {};

  static void init() {
    LoggingConfig.applyForCurrentMode();
    if (LoggingConfig.writePerfToFile) {
      unawaited(PerfSessionLog.ensureSessionFile());
    }
  }

  static void error(
    LogCategory category,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    _emit(
      LogLevel.error,
      category,
      message,
      error: error,
      stackTrace: stackTrace,
    );
  }

  static void warning(LogCategory category, String message) {
    _emit(LogLevel.warning, category, message);
  }

  static void info(LogCategory category, String message) {
    _emit(LogLevel.info, category, message);
  }

  static void debug(LogCategory category, String message) {
    _emit(LogLevel.debug, category, message);
  }

  /// Performance / timing line — also written to [PerfSessionLog] when enabled.
  static void perf(String event, {Map<String, Object?> fields = const {}}) {
    final parts = <String>[
      event,
      for (final e in fields.entries)
        if (e.value != null) '${e.key}=${e.value}',
    ];
    final line = parts.join(' ');
    _emit(LogLevel.info, LogCategory.perf, line, mirrorToPerfFile: true);
  }

  /// User-facing KPI (tap-to-frame, etc.).
  static void metric(String name, {Map<String, Object?> fields = const {}}) {
    final parts = <String>[
      name,
      for (final e in fields.entries)
        if (e.value != null) '${e.key}=${e.value}',
    ];
    final line = parts.join(' ');
    _emit(LogLevel.info, LogCategory.metric, line, mirrorToPerfFile: true);
  }

  /// Rate-limit identical keys (pool skip, lifecycle mismatch, etc.).
  static void debugThrottled(
    LogCategory category,
    String throttleKey,
    String message, {
    Duration interval = const Duration(seconds: 15),
  }) {
    final now = DateTime.now();
    final prev = _throttle[throttleKey];
    if (prev != null && now.difference(prev) < interval) return;
    _throttle[throttleKey] = now;
    debug(category, message);
  }

  static void _emit(
    LogLevel level,
    LogCategory category,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    bool mirrorToPerfFile = false,
  }) {
    if (!LoggingConfig.enabled && level != LogLevel.error) return;
    if (level.priority > LoggingConfig.minConsoleLevel.priority) return;

    final cats = LoggingConfig.categories;
    if (cats.isNotEmpty && !cats.contains(category)) {
      if (level != LogLevel.error) return;
    }

    final tag = _tagFor(category);
    final ts = DateTime.now().toIso8601String();
    final line = '[$ts][$tag][${level.label}] $message';

    if (mirrorToPerfFile && LoggingConfig.writePerfToFile) {
      unawaited(PerfSessionLog.append(line));
    }

    debugPrint(line);
    if (error != null) {
      debugPrint('  error: $error');
    }
    if (stackTrace != null) {
      debugPrint('  $stackTrace');
    }
  }

  static String _tagFor(LogCategory c) {
    switch (c) {
      case LogCategory.error:
        return 'ERR';
      case LogCategory.warning:
        return 'WARN';
      case LogCategory.perf:
        return 'PERF';
      case LogCategory.metric:
        return 'METRIC';
      case LogCategory.explore:
        return 'EXPLORE';
      case LogCategory.reel:
        return 'REEL';
      case LogCategory.pool:
        return 'POOL';
      case LogCategory.lifecycle:
        return 'LIFE';
      case LogCategory.memory:
        return 'MEM';
      case LogCategory.firebase:
        return 'FS';
      case LogCategory.resolver:
        return 'RESOLVE';
      case LogCategory.general:
        return 'APP';
    }
  }
}
