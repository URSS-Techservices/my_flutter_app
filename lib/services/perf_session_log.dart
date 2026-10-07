import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'logging_config.dart';

/// Ring buffer + on-disk session log for sharing with debugging sessions.
class PerfSessionLog {
  PerfSessionLog._();

  static final List<String> _buffer = [];
  static File? _sessionFile;
  static String? _sessionPath;

  static String? get sessionPath => _sessionPath;

  static Future<void> ensureSessionFile() async {
    if (_sessionFile != null) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final logsDir = Directory('${dir.path}/perf_logs');
      if (!logsDir.existsSync()) {
        logsDir.createSync(recursive: true);
      }
      final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
      final file = File('${logsDir.path}/perf_session_$stamp.log');
      await file.writeAsString(
        '# Halo perf session $stamp\n'
        '# Pull with: adb pull ${file.path}\n'
        '# Or copy from app files (perf_logs/) on device.\n\n',
      );
      _sessionFile = file;
      _sessionPath = file.path;
      debugPrint('[PERF_FILE] writing to $_sessionPath');
    } catch (e) {
      debugPrint('[PERF_FILE] could not create session file: $e');
    }
  }

  static Future<void> append(String line) async {
    _buffer.add(line);
    final max = LoggingConfig.perfBufferMaxLines;
    if (_buffer.length > max) {
      _buffer.removeRange(0, _buffer.length - max);
    }
    final file = _sessionFile;
    if (file == null) return;
    try {
      await file.writeAsString('$line\n', mode: FileMode.append);
    } catch (_) {}
  }

  /// Snapshot for clipboard / chat paste (last N lines).
  static String snapshot({int maxLines = 120}) {
    if (_buffer.isEmpty) return '(no perf lines yet)';
    final start = _buffer.length > maxLines ? _buffer.length - maxLines : 0;
    final header = _sessionPath == null
        ? '# perf snapshot'
        : '# perf snapshot\n# file: $_sessionPath\n';
    return '$header\n${_buffer.sublist(start).join('\n')}';
  }

  static Future<String> exportSummary() async {
    await ensureSessionFile();
    final path = _sessionPath ?? '(no file)';
    final summary = StringBuffer()
      ..writeln('=== PERF SESSION SUMMARY ===')
      ..writeln('file: $path')
      ..writeln('lines: ${_buffer.length}')
      ..writeln('--- last events ---')
      ..writeln(snapshot(maxLines: 200));
    final text = summary.toString();
    debugPrint(text);
    return text;
  }

  static void clear() {
    _buffer.clear();
  }
}
