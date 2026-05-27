/// Heap-pressure watchdog for the reels feed.
///
/// Polls Dart VM RSS every second and emits three thresholds:
///   * 180 MB  → pause new preloads
///   * 220 MB  → force-dispose the oldest pooled player
///   * 240 MB  → emergency: dispose everything except the current reel
///
/// `MemoryWatchdog` is platform-portable (uses `ProcessInfo.currentRss`) and
/// callers listen via [stream] or query the live [state] / [rssMb] fields.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

enum MemoryPressure { ok, soft, hard, critical }

class MemoryWatchdogEvent {
  final MemoryPressure pressure;
  final int rssMb;
  const MemoryWatchdogEvent(this.pressure, this.rssMb);
}

class MemoryWatchdog {
  MemoryWatchdog._();
  static final MemoryWatchdog instance = MemoryWatchdog._();

  static const int kSoftMb = 180;
  static const int kHardMb = 220;
  static const int kCriticalMb = 240;

  final StreamController<MemoryWatchdogEvent> _controller =
      StreamController<MemoryWatchdogEvent>.broadcast();
  Timer? _timer;
  MemoryPressure _state = MemoryPressure.ok;
  int _rssMb = 0;

  Stream<MemoryWatchdogEvent> get stream => _controller.stream;
  MemoryPressure get state => _state;
  int get rssMb => _rssMb;

  void start({Duration interval = const Duration(seconds: 1)}) {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => _tick());
    _tick();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _tick() {
    int rss;
    try {
      rss = ProcessInfo.currentRss;
    } catch (_) {
      return;
    }
    _rssMb = (rss / (1024 * 1024)).round();

    final next = _classify(_rssMb);
    if (next != _state) {
      _state = next;
      debugPrint(
        '[MemoryWatchdog] state=$next rss=${_rssMb}MB '
        '(soft=$kSoftMb hard=$kHardMb critical=$kCriticalMb)',
      );
      _controller.add(MemoryWatchdogEvent(next, _rssMb));
    }
  }

  MemoryPressure _classify(int mb) {
    if (mb >= kCriticalMb) return MemoryPressure.critical;
    if (mb >= kHardMb) return MemoryPressure.hard;
    if (mb >= kSoftMb) return MemoryPressure.soft;
    return MemoryPressure.ok;
  }
}
