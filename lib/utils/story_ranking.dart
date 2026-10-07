// Pure functions for story strip ranking. Client-side only.

/// Newer stories score higher. Formula: 1 / (hoursAgo + 1).
double recencyScore(DateTime createdAt) {
  final hoursAgo = DateTime.now().difference(createdAt).inHours;
  return 1.0 / (hoursAgo + 1);
}

/// 1.0 if current user has not viewed any of the stories, else 0.0.
double unseenScore(List<String> viewers, String currentUserId) {
  if (currentUserId.isEmpty) return 1.0;
  return viewers.contains(currentUserId) ? 0.0 : 1.0;
}

/// Weighted sum: unseen 0.4, relationship 0.3, recency 0.3.
double storyScore({
  required DateTime createdAt,
  required List<String> viewers,
  required double relationshipScore,
  required String currentUserId,
}) {
  final u = unseenScore(viewers, currentUserId);
  final r = recencyScore(createdAt);
  final rel = relationshipScore.clamp(0.0, 1.0);
  return u * 0.4 + rel * 0.3 + r * 0.3;
}
