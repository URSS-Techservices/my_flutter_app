import 'package:halo/features/search/domain/search_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CATEGORY FEED
// What the user sees after opening a subcategory (e.g. Fitness): people grouped
// by profile type (guru / wellness / aspirant), and inside each group ordered
// into sections — people you know, matching interests, popular, new, nearby,
// everyone else. Pure Dart, no Firebase: easy to test and to tune from the
// admin-editable [SearchConfig].
// ─────────────────────────────────────────────────────────────────────────────

const List<String> kProfileTypes = ['guru', 'wellness', 'aspirant'];

enum FeedSectionType { network, interest, popular, fresh, nearby, others }

class FeedSection {
  final FeedSectionType type;
  final String title;
  final List<UserResult> users;

  const FeedSection({
    required this.type,
    required this.title,
    required this.users,
  });
}

class CategoryFeed {
  /// profile type ('guru' | 'wellness' | 'aspirant') → ordered sections.
  final Map<String, List<FeedSection>> sectionsByType;

  const CategoryFeed(this.sectionsByType);

  static const empty = CategoryFeed({});

  List<FeedSection> sectionsFor(String profileType) =>
      sectionsByType[profileType] ?? const [];

  int countFor(String profileType) =>
      sectionsFor(profileType).fold(0, (n, s) => n + s.users.length);

  bool get isEmpty => kProfileTypes.every((t) => countFor(t) == 0);
}

// ─────────────────────────────────────────────────────────────────────────────
// SEARCH CONFIG — Firestore doc `search_config/main` (admin editable)
// ─────────────────────────────────────────────────────────────────────────────

class SearchConfig {
  final List<FeedSectionType> sectionOrder;
  final Set<FeedSectionType> disabled;
  final int sectionLimit;
  final int othersLimit;
  final int newDays;
  final Map<FeedSectionType, String> titles;

  const SearchConfig({
    this.sectionOrder = const [
      FeedSectionType.network,
      FeedSectionType.interest,
      FeedSectionType.popular,
      FeedSectionType.fresh,
      FeedSectionType.nearby,
      FeedSectionType.others,
    ],
    // Nearby starts switched off; an admin can enable it from Firebase.
    this.disabled = const {FeedSectionType.nearby},
    this.sectionLimit = 20,
    this.othersLimit = 40,
    this.newDays = 30,
    this.titles = const {},
  });

  static const defaultTitles = {
    FeedSectionType.network: 'People you know',
    FeedSectionType.interest: 'Matches your interests',
    FeedSectionType.popular: 'Popular',
    FeedSectionType.fresh: 'New on Halo',
    FeedSectionType.nearby: 'Near you',
    FeedSectionType.others: 'More people',
  };

  String titleFor(FeedSectionType t) => titles[t] ?? defaultTitles[t]!;

  /// Tolerant parser: anything missing or malformed falls back to defaults.
  factory SearchConfig.fromMap(Map<String, dynamic>? m) {
    if (m == null) return const SearchConfig();
    const d = SearchConfig();

    FeedSectionType? typeOf(Object? name) {
      for (final t in FeedSectionType.values) {
        if (t.name == name) return t;
      }
      return null;
    }

    final order = (m['sectionOrder'] as List?)
        ?.map(typeOf)
        .whereType<FeedSectionType>()
        .toList();

    final enabled = m['enabledSections'];
    final disabled = <FeedSectionType>{...d.disabled};
    if (enabled is Map) {
      for (final t in FeedSectionType.values) {
        final v = enabled[t.name];
        if (v is bool) v ? disabled.remove(t) : disabled.add(t);
      }
    }

    final titles = <FeedSectionType, String>{};
    final rawTitles = m['titles'];
    if (rawTitles is Map) {
      for (final t in FeedSectionType.values) {
        final v = rawTitles[t.name];
        if (v is String && v.trim().isNotEmpty) titles[t] = v.trim();
      }
    }

    int intOr(Object? v, int fallback) =>
        (v is num && v > 0) ? v.toInt() : fallback;

    return SearchConfig(
      sectionOrder: (order == null || order.isEmpty) ? d.sectionOrder : order,
      disabled: disabled,
      sectionLimit: intOr(m['sectionLimit'], d.sectionLimit),
      othersLimit: intOr(m['othersLimit'], d.othersLimit),
      newDays: intOr(m['newDays'], d.newDays),
      titles: titles,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RANKER
// Each person appears once, in the first enabled section (in config order)
// that fits them.
// ─────────────────────────────────────────────────────────────────────────────

CategoryFeed buildCategoryFeed({
  required List<UserResult> users,
  required String? currentUserId,
  required Set<String> followingIds,
  required Set<String> followerIds,
  required List<String> myTags,
  required String myLocation,
  required SearchConfig config,
  DateTime? now,
}) {
  final clock = now ?? DateTime.now();
  final myTagSet = myTags.toSet();
  final myCity = _cityOf(myLocation);

  FollowRelation relationOf(String id) {
    final following = followingIds.contains(id);
    final follower = followerIds.contains(id);
    if (following && follower) return FollowRelation.mutual;
    if (following) return FollowRelation.following;
    if (follower) return FollowRelation.follower;
    return FollowRelation.none;
  }

  int overlap(UserResult u) => u.interestTags.where(myTagSet.contains).length;

  int relationRank(FollowRelation r) => switch (r) {
        FollowRelation.mutual => 3,
        FollowRelation.following => 2,
        FollowRelation.follower => 1,
        _ => 0,
      };

  int byFollowers(UserResult a, UserResult b) =>
      b.followersCount.compareTo(a.followersCount);

  final groups = <String, List<UserResult>>{};
  for (final u in users) {
    if (u.userId == currentUserId) continue;
    final type =
        kProfileTypes.contains(u.accountType) ? u.accountType : 'aspirant';
    groups
        .putIfAbsent(type, () => [])
        .add(u.copyWith(relation: relationOf(u.userId)));
  }

  List<UserResult> pick(FeedSectionType type, List<UserResult> pool) {
    final limit = config.sectionLimit;
    switch (type) {
      case FeedSectionType.network:
        return (pool.where((u) => relationRank(u.relation) > 0).toList()
              ..sort((a, b) {
                final r = relationRank(b.relation)
                    .compareTo(relationRank(a.relation));
                if (r != 0) return r;
                final o = overlap(b).compareTo(overlap(a));
                return o != 0 ? o : byFollowers(a, b);
              }))
            .take(limit)
            .toList();
      case FeedSectionType.interest:
        return (pool.where((u) => overlap(u) > 0).toList()
              ..sort((a, b) {
                final o = overlap(b).compareTo(overlap(a));
                if (o != 0) return o;
                if (a.isFeatured != b.isFeatured) return a.isFeatured ? -1 : 1;
                return byFollowers(a, b);
              }))
            .take(limit)
            .toList();
      case FeedSectionType.popular:
        return (List.of(pool)
              ..sort((a, b) {
                if (a.isFeatured != b.isFeatured) return a.isFeatured ? -1 : 1;
                return byFollowers(a, b);
              }))
            .take(limit)
            .toList();
      case FeedSectionType.fresh:
        return (pool
                .where((u) =>
                    u.joinedAt != null &&
                    clock.difference(u.joinedAt!).inDays <= config.newDays)
                .toList()
              ..sort((a, b) => b.joinedAt!.compareTo(a.joinedAt!)))
            .take(limit)
            .toList();
      case FeedSectionType.nearby:
        if (myCity.isEmpty) return const [];
        return (pool
                .where((u) => u.location.toLowerCase().contains(myCity))
                .toList()
              ..sort(byFollowers))
            .take(limit)
            .toList();
      case FeedSectionType.others:
        return (List.of(pool)..sort(byFollowers))
            .take(config.othersLimit)
            .toList();
    }
  }

  final result = <String, List<FeedSection>>{};
  groups.forEach((profileType, group) {
    final remaining = List<UserResult>.of(group);
    final sections = <FeedSection>[];
    for (final type in config.sectionOrder) {
      if (config.disabled.contains(type)) continue;
      final picked = pick(type, remaining);
      if (picked.isEmpty) continue;
      final ids = picked.map((u) => u.userId).toSet();
      remaining.removeWhere((u) => ids.contains(u.userId));
      sections.add(FeedSection(
        type: type,
        title: config.titleFor(type),
        users: picked,
      ));
    }
    result[profileType] = sections;
  });

  return CategoryFeed(result);
}

/// "Lucknow, Uttar Pradesh" → "lucknow".
String _cityOf(String location) =>
    location.split(',').first.trim().toLowerCase();
