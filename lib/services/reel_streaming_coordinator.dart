class ReelStreamEntry {
  final String reelId;
  final String playbackUrl;
  final String fallbackUrl;

  const ReelStreamEntry({
    required this.reelId,
    required this.playbackUrl,
    this.fallbackUrl = '',
  });
}

class ReelViewportDecision {
  final Set<String> hotIds;
  final List<String> preloadUrls;
  final List<String> releaseUrls;
  final int aheadWindow;
  final int behindWindow;

  const ReelViewportDecision({
    required this.hotIds,
    required this.preloadUrls,
    required this.releaseUrls,
    required this.aheadWindow,
    required this.behindWindow,
  });
}

class ReelStreamingCoordinator {
  /// Aligned with [ReelPlatformPolicy.maxPoolSlots]: warm only current + next.
  ReelStreamingCoordinator({
    this.defaultAhead = 1,
    this.fastSwipeAhead = 1,
    this.behind = 0,
  });

  final int defaultAhead;
  final int fastSwipeAhead;
  final int behind;

  final Set<String> _lastHotIds = <String>{};
  DateTime? _lastPageChangeAt;

  int _computeAheadWindow() {
    final now = DateTime.now();
    final last = _lastPageChangeAt;
    _lastPageChangeAt = now;
    if (last == null) return defaultAhead;
    final delta = now.difference(last).inMilliseconds;
    return delta <= 220 ? fastSwipeAhead : defaultAhead;
  }

  ReelViewportDecision onViewportChanged({
    required List<ReelStreamEntry> entries,
    required int currentIndex,
    bool lowMemoryMode = false,
    /// While the tapped reel is still starting up, only warm the current item
    /// so we do not spin up a second decoder before first frame.
    bool startupOnly = false,
  }) {
    final safeIndex = currentIndex.clamp(0, entries.isEmpty ? 0 : entries.length - 1);
    if (startupOnly) {
      final e = entries[safeIndex];
      return ReelViewportDecision(
        hotIds: {e.reelId},
        preloadUrls:
            e.playbackUrl.isNotEmpty ? <String>[e.playbackUrl] : const [],
        releaseUrls: const [],
        aheadWindow: 0,
        behindWindow: 0,
      );
    }
    final ahead = lowMemoryMode ? 1 : _computeAheadWindow();
    final back = lowMemoryMode ? 0 : behind;

    final hot = <String>{};
    final preloadUrls = <String>[];
    final releaseUrls = <String>[];

    for (int i = safeIndex - back; i <= safeIndex + ahead; i++) {
      if (i < 0 || i >= entries.length) continue;
      final e = entries[i];
      hot.add(e.reelId);
      if (e.playbackUrl.isNotEmpty) preloadUrls.add(e.playbackUrl);
    }

    final releaseIds = _lastHotIds.difference(hot);
    if (releaseIds.isNotEmpty) {
      for (final e in entries) {
        if (!releaseIds.contains(e.reelId)) continue;
        if (e.playbackUrl.isNotEmpty) releaseUrls.add(e.playbackUrl);
      }
    }

    _lastHotIds
      ..clear()
      ..addAll(hot);

    return ReelViewportDecision(
      hotIds: hot,
      preloadUrls: preloadUrls,
      releaseUrls: releaseUrls,
      aheadWindow: ahead,
      behindWindow: back,
    );
  }
}
