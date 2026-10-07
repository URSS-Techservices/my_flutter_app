// Pure functions for weighted feed ranking. No ML, client-side only.

/// Newer posts score higher. Uses hours since creation.
/// Formula: 1 / (hoursAgo + 1) so 0h => 1.0, 24h => ~0.04.
double recencyScore(DateTime createdAt) {
  final hoursAgo = DateTime.now().difference(createdAt).inHours;
  return 1.0 / (hoursAgo + 1);
}

/// Engagement: saves weighted highest, then comments, then likes.
/// Normalized to 0..1 using 1 - 1/(1 + raw/20).
double engagementScore(int likes, int comments, int saves) {
  const wLikes = 1.0, wComments = 2.0, wSaves = 3.0;
  final raw = (likes * wLikes) + (comments * wComments) + (saves * wSaves);
  return 1.0 - (1.0 / (1.0 + raw / 20.0));
}

/// Content preference: 1.0 if post type matches user preference, else 0.5.
double interestScore(String postType, String userPreference) {
  if (userPreference.isEmpty) return 0.75;
  return postType.toLowerCase() == userPreference.toLowerCase() ? 1.0 : 0.5;
}

/// Weighted sum: recency 0.4, relationship 0.3, engagement 0.2, interest 0.1.
double feedScore({
  required DateTime createdAt,
  required double relationshipScore,
  required int likes,
  required int comments,
  required int saves,
  required String postType,
  required String userPreference,
}) {
  final r = recencyScore(createdAt);
  final e = engagementScore(likes, comments, saves);
  final i = interestScore(postType, userPreference);
  final rel = relationshipScore.clamp(0.0, 1.0);
  return r * 0.4 + rel * 0.3 + e * 0.2 + i * 0.1;
}
