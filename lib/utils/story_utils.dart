import '../models/story_model.dart';

/// Groups stories by userId. Each user's list is sorted by createdAt (oldest first, like Instagram).
Map<String, List<StoryModel>> groupStoriesByUser(List<StoryModel> stories) {
  final Map<String, List<StoryModel>> grouped = {};

  for (var story in stories) {
    grouped.putIfAbsent(story.userId, () => []);
    grouped[story.userId]!.add(story);
  }

  // Sort each user's stories by createdAt ascending (oldest first = first posted first)
  for (var key in grouped.keys) {
    grouped[key]!.sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  return grouped;
}

/// Returns userIds in Instagram order: current user first, then others (unseen first, then by latest story).
List<String> storyDisplayOrder(
  Map<String, List<StoryModel>> groupedStories,
  String? myUid,
) {
  if (groupedStories.isEmpty) return [];
  final keys = groupedStories.keys.toList();
  if (myUid == null || myUid.isEmpty) return keys;

  final others = keys.where((id) => id != myUid).toList();
  final unseenFirst = others.where((id) {
    final list = groupedStories[id] ?? [];
    return list.any((s) => !s.viewers.contains(myUid));
  }).toList();
  final seen = others.where((id) => !unseenFirst.contains(id)).toList();

  DateTime latestTime(String uid) {
    final list = groupedStories[uid] ?? [];
    if (list.isEmpty) return DateTime(0);
    return list.map((s) => s.createdAt).reduce((a, b) => a.isAfter(b) ? a : b);
  }
  unseenFirst.sort((a, b) => latestTime(b).compareTo(latestTime(a)));
  seen.sort((a, b) => latestTime(b).compareTo(latestTime(a)));

  return [myUid, ...unseenFirst, ...seen];
}
