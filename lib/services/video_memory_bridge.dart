import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:halo/Bottom Pages/ExplorePage.dart';
import 'package:halo/Bottom Pages/HomePage.dart';
import 'package:halo/services/app_logger.dart';
import 'package:halo/services/memory_watchdog.dart';

/// Subscribes to [MemoryWatchdog] and applies pressure actions across video pools.
class VideoMemoryBridge {
  VideoMemoryBridge._();

  static StreamSubscription<MemoryWatchdogEvent>? _sub;
  static bool _installed = false;

  static void install() {
    if (_installed || kIsWeb) return;
    _installed = true;
    if (!kDebugMode && !kProfileMode) return;

    // Defer polling until after Firebase/GMS init — avoids critical RSS at ~220MB
    // on cold start with no video pool entries yet.
    Future<void>.delayed(const Duration(seconds: 20), () {
      if (!_installed) return;
      MemoryWatchdog.instance.start();
      _sub?.cancel();
      _sub = MemoryWatchdog.instance.stream.listen(_onEvent);
      AppLogger.perf('video_memory_bridge_installed');
    });
  }

  static void dispose() {
    _sub?.cancel();
    _sub = null;
    MemoryWatchdog.instance.stop();
    _installed = false;
  }

  static void _onEvent(MemoryWatchdogEvent event) {
    final pool = VideoControllerPool.instance;
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
          evictHomeFeedVideoCache();
        }
        AppLogger.perf('memory_critical', fields: {
          'rssMb': event.rssMb,
          'pooled': pool.pooledCount,
        });
        break;
    }
  }
}
