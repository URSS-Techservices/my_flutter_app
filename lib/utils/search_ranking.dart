import 'dart:math' as math;

/// exact match -> 1.0, prefix match -> 0.8, contains keyword -> 0.4, no match -> 0.0
double textMatchScore(String text, String query) {
  final t = text.trim().toLowerCase();
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return 0.0;
  if (t.isEmpty) return 0.0;
  if (t == q) return 1.0;
  if (t.startsWith(q)) return 0.8;
  if (t.contains(q)) return 0.4;
  return 0.0;
}

/// Best text match across words of [query] against [text].
double textMatchScoreMultiWord(String text, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return 0.0;
  final words = q.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
  if (words.isEmpty) return textMatchScore(text, query);
  double best = 0.0;
  for (final w in words) {
    final s = textMatchScore(text, w);
    if (s > best) best = s;
  }
  return best;
}

double _followerScore(int followersCount) {
  if (followersCount <= 0) return 0.0;
  final x = math.log(followersCount + 1) / math.log(10) / 5.0;
  return x.clamp(0.0, 1.0);
}

double _recencyScoreDays(DateTime lastActiveAt) {
  final daysAgo = DateTime.now().difference(lastActiveAt).inDays;
  return 1.0 / (daysAgo + 1);
}

double userSearchScore({
  required String username,
  required String name,
  required String bio,
  required double relationshipScore,
  required int followersCount,
  required DateTime lastActiveAt,
  required String query,
}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return 0.0;

  final usernameMatch = textMatchScoreMultiWord(username, query);
  final nameMatch = textMatchScoreMultiWord(name, query);
  final bioMatch = textMatchScoreMultiWord(bio, query);
  final rel = relationshipScore.clamp(0.0, 1.0);
  final followerScore = _followerScore(followersCount);
  final recencyScore = _recencyScoreDays(lastActiveAt);

  return usernameMatch * 0.4 +
      nameMatch * 0.2 +
      bioMatch * 0.1 +
      rel * 0.15 +
      followerScore * 0.1 +
      recencyScore * 0.05;
}

double _engagementScore(int likes, int comments, int saves) {
  final raw = (likes * 1.0 + comments * 2.0 + saves * 3.0) / 100.0;
  return raw.clamp(0.0, 1.0);
}

double postSearchScore({
  required String caption,
  required List<String> tags,
  required int likes,
  required int comments,
  required int saves,
  required DateTime createdAt,
  required String query,
}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return 0.0;

  final captionMatch = textMatchScoreMultiWord(caption, query);
  double tagMatch = 0.0;
  for (final tag in tags) {
    final s = textMatchScore(tag.trim().toLowerCase(), q);
    if (s > tagMatch) tagMatch = s;
  }
  final engagementScore = _engagementScore(likes, comments, saves);
  final daysAgo = DateTime.now().difference(createdAt).inDays;
  final recencyScore = 1.0 / (daysAgo + 1);

  return captionMatch * 0.4 +
      tagMatch * 0.2 +
      engagementScore * 0.25 +
      recencyScore * 0.15;
}
