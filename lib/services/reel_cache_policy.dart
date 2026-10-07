import 'dart:collection';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class ReelCachePolicy {
  ReelCachePolicy({
    required this.cacheManager,
    this.warmRetentionLimit = 7,
  }) : assert(warmRetentionLimit >= 1);

  final CacheManager cacheManager;
  final int warmRetentionLimit;

  final Queue<String> _warmQueue = Queue<String>();
  final Set<String> _warmSet = <String>{};
  final Set<String> _hotIds = <String>{};

  Set<String> get hotIds => Set.unmodifiable(_hotIds);
  Set<String> get warmIds => Set.unmodifiable(_warmSet);

  void replaceHotSet(Set<String> ids) {
    _hotIds
      ..clear()
      ..addAll(ids);
  }

  Future<void> markWatched({
    required String reelId,
    required String mediaUrl,
  }) async {
    if (reelId.isEmpty || mediaUrl.isEmpty) return;

    if (_warmSet.contains(reelId)) {
      _warmQueue.remove(reelId);
      _warmQueue.addLast(reelId);
      return;
    }

    _warmSet.add(reelId);
    _warmQueue.addLast(reelId);
    await _trimIfNeeded();
  }

  Future<void> _trimIfNeeded() async {
    while (_warmQueue.length > warmRetentionLimit) {
      final victim = _warmQueue.removeFirst();
      _warmSet.remove(victim);
    }
  }

  Future<void> evictMediaByUrl(String url) async {
    if (url.isEmpty) return;
    try {
      await cacheManager.removeFile(url);
    } catch (_) {}
  }

  void clearWarmQueue() {
    _warmQueue.clear();
    _warmSet.clear();
    _hotIds.clear();
  }
}
