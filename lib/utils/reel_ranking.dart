// Pure functions for short-form video (reels) virality scoring. Client-side only.

/// Fraction of total possible watch time actually watched. Clamped to 0..1.
double watchTimeRatio({
  required int totalWatchTime,
  required int views,
  required int durationSeconds,
}) {
  if (views <= 0 || durationSeconds <= 0) return 0.0;
  final possible = views * durationSeconds;
  if (possible <= 0) return 0.0;
  final ratio = totalWatchTime / possible;
  return ratio.clamp(0.0, 1.0);
}

/// completedViews / views when views > 0; else 0.
double completionRate({required int views, required int completedViews}) {
  if (views <= 0) return 0.0;
  return (completedViews / views).clamp(0.0, 1.0);
}

/// replayCount / views when views > 0; else 0. Not clamped (can be > 1).
double replayRate({required int views, required int replayCount}) {
  if (views <= 0) return 0.0;
  final rate = replayCount / views;
  return rate.clamp(0.0, 10.0);
}

/// (likes*1 + comments*2 + shares*3) / views. Normalized for score: use min(1, raw/50).
double engagementScore({
  required int views,
  required int likes,
  required int comments,
  required int shares,
}) {
  if (views <= 0) return 0.0;
  final raw = (likes * 1.0 + comments * 2.0 + shares * 3.0) / views;
  return (raw / 50.0).clamp(0.0, 1.0);
}

/// 1 / (hoursAgo + 1). Newer reels get a small boost.
double recencyScore(DateTime createdAt) {
  final hoursAgo = DateTime.now().difference(createdAt).inHours;
  return 1.0 / (hoursAgo + 1);
}

/// Weighted sum: watchTime 0.4, completion 0.2, replay 0.2, engagement 0.1, recency 0.1.
/// replayRate normalized to 0..1 via min(1, replayRate).
double reelScore({
  required int totalWatchTime,
  required int views,
  required int durationSeconds,
  required int completedViews,
  required int replayCount,
  required int likes,
  required int comments,
  required int shares,
  required DateTime createdAt,
}) {
  final wt = watchTimeRatio(
    totalWatchTime: totalWatchTime,
    views: views,
    durationSeconds: durationSeconds,
  );
  final comp = completionRate(views: views, completedViews: completedViews);
  final replay = replayRate(views: views, replayCount: replayCount);
  final replayNorm = replay.clamp(0.0, 1.0);
  final eng = engagementScore(
    views: views,
    likes: likes,
    comments: comments,
    shares: shares,
  );
  final rec = recencyScore(createdAt);

  return wt * 0.4 + comp * 0.2 + replayNorm * 0.2 + eng * 0.1 + rec * 0.1;
}
