/// Shared coordinator for all video controller pools in the app.
///
/// Two separate pools exist — [VideoControllerPool] (explore/reels tab) and
/// [_FeedVideoPool] (home feed reel viewer). Both register dispose/evict
/// callbacks here so [VideoMemoryBridge] can drain them on memory pressure
/// without importing each individual pool.
library;

typedef PoolVoidCallback = void Function();

class VideoPoolCoordinator {
  VideoPoolCoordinator._();
  static final VideoPoolCoordinator instance = VideoPoolCoordinator._();

  // ── Pressure flag ──────────────────────────────────────────────────────────
  bool _pauseNewPreloads = false;

  bool get pauseNewPreloads => _pauseNewPreloads;
  set pauseNewPreloads(bool value) {
    if (_pauseNewPreloads == value) return;
    _pauseNewPreloads = value;
  }

  // ── Pool callbacks registered by actual pool implementations ──────────────
  final List<PoolVoidCallback> _evictOldestCbs = [];
  final List<PoolVoidCallback> _disposeAllCbs = [];
  final List<int Function()> _countCbs = [];

  void registerEvictOldest(PoolVoidCallback cb) => _evictOldestCbs.add(cb);
  void registerDisposeAll(PoolVoidCallback cb) => _disposeAllCbs.add(cb);
  void registerCount(int Function() cb) => _countCbs.add(cb);

  void unregisterEvictOldest(PoolVoidCallback cb) => _evictOldestCbs.remove(cb);
  void unregisterDisposeAll(PoolVoidCallback cb) => _disposeAllCbs.remove(cb);
  void unregisterCount(int Function() cb) => _countCbs.remove(cb);

  // ── Aggregate operations ────────────────────────────────────────────────────
  int get pooledCount {
    int total = 0;
    for (final cb in _countCbs) {
      total += cb();
    }
    return total;
  }

  void evictOldest() {
    for (final cb in List.of(_evictOldestCbs)) {
      cb();
    }
  }

  void disposeAll() {
    for (final cb in List.of(_disposeAllCbs)) {
      cb();
    }
  }
}
