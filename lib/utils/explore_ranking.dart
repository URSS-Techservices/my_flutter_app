// Pure functions for Explore page ranking. Client-side only.

/// Fraction of post tags that match user interests. 0 if post has no tags.
double interestScore(List<String> postTags, List<String> userInterests) {
  if (postTags.isEmpty) return 0.0;
  if (userInterests.isEmpty) return 0.0;
  final lower = userInterests.map((e) => e.toString().toLowerCase()).toSet();
  final match = postTags.where((t) => lower.contains(t.toString().toLowerCase())).length;
  return match / postTags.length;
}

/// (likes*1 + comments*2 + saves*3) / 100, clamped to 0..1.
double engagementScore(int likes, int comments, int saves) {
  final raw = (likes * 1.0 + comments * 2.0 + saves * 3.0) / 100.0;
  return raw.clamp(0.0, 1.0);
}

/// Newer posts score higher. 1 / (hoursAgo + 1).
double recencyScore(DateTime createdAt) {
  final hoursAgo = DateTime.now().difference(createdAt).inHours;
  return 1.0 / (hoursAgo + 1);
}

/// Weighted sum: interest 0.5, engagement 0.3, recency 0.2.
double exploreScore({
  required List<String> postTags,
  required List<String> userInterests,
  required int likes,
  required int comments,
  required int saves,
  required DateTime createdAt,
}) {
  final i = interestScore(postTags, userInterests);
  final e = engagementScore(likes, comments, saves);
  final r = recencyScore(createdAt);
  return i * 0.5 + e * 0.3 + r * 0.2;
}

/// Same scoring components as [exploreScore], but lets the caller shift
/// weights between “interest-first” vs “discovery/more variety”.
double exploreScoreWithWeights({
  required List<String> postTags,
  required List<String> userInterests,
  required int likes,
  required int comments,
  required int saves,
  required DateTime createdAt,
  required double interestWeight,
  required double engagementWeight,
  required double recencyWeight,
}) {
  final i = interestScore(postTags, userInterests);
  final e = engagementScore(likes, comments, saves);
  final r = recencyScore(createdAt);

  final sum = interestWeight + engagementWeight + recencyWeight;
  if (sum <= 0) return 0.0;

  final iw = interestWeight / sum;
  final ew = engagementWeight / sum;
  final rw = recencyWeight / sum;
  return i * iw + e * ew + r * rw;
}
