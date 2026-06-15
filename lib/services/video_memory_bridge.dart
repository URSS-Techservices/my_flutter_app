import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:halo/services/app_logger.dart';
import 'package:halo/services/memory_watchdog.dart';
import 'package:halo/services/video_controller_pool.dart';

/// Subscribes to [MemoryWatchdog] and applies pressure actions across all
/// registered video pools via [VideoPoolCoordinator].
class VideoMemoryBridge {
  VideoMemoryBridge._();

  static StreamSubscription<MemoryWatchdogEvent>? _sub;
  static bool _installed = false;

  static void install() {
    if (_installed || kIsWeb) return;
    _installed = true;

    // Defer polling until after Firebase/GMS init — avoids critical RSS at
    // ~220 MB on cold start with no video pool entries yet.
    Future<void>.delayed(const Duration(seconds: 30), () {
      if (!_installed) return;
      MemoryWatchdog.instance.start();
      _sub?.cancel();
      _sub = MemoryWatchdog.instance.stream.listen(_onEvent);
      AppLogger.perf('video_memory_bridge_installed', fields: {
        'mode': kDebugMode
            ? 'debug'
            : (kProfileMode ? 'profile' : 'release'),
      });
    });
  }

  static void dispose() {
    _sub?.cancel();
    _sub = null;
    MemoryWatchdog.instance.stop();
    _installed = false;
  }

  static void _onEvent(MemoryWatchdogEvent event) {
    final pool = VideoPoolCoordinator.instance;
    switch (event.pressure) {
      case MemoryPressure.ok:
        pool.pauseNewPreloads = false;
        break;
      case MemoryPressure.soft:
        pool.pauseNewPreloads = true;
        AppLogger.perf('memory_soft', fields: {'rssMb': event.rssMb});
        break;
      case MemoryPressure.hard:
        pool.pauseNewPreloads = true;
        pool.evictOldest();
        AppLogger.perf('memory_hard', fields: {'rssMb': event.rssMb});
        break;
      case MemoryPressure.critical:
        pool.pauseNewPreloads = true;
        if (pool.pooledCount > 0) {
          pool.disposeAll();
        }
        AppLogger.perf('memory_critical', fields: {
          'rssMb': event.rssMb,
          'pooled': pool.pooledCount,
        });
        break;
    }
  }
}
