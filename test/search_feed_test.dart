import 'package:flutter_test/flutter_test.dart';
import 'package:halo/features/search/domain/category_feed.dart';
import 'package:halo/features/search/domain/interest_tags.dart';
import 'package:halo/features/search/domain/search_models.dart';

UserResult _u(
  String id, {
  String type = 'guru',
  int followers = 0,
  List<String> tags = const [],
  String location = '',
  DateTime? joined,
  bool featured = false,
}) =>
    UserResult(
      userId: id,
      name: id,
      username: id,
      accountType: type,
      followersCount: followers,
      interestTags: tags,
      location: location,
      joinedAt: joined,
      isFeatured: featured,
    );

void main() {
  test('normalizeTag matches the Cloud Function', () {
    expect(normalizeTag('Yoga & Breathwork'), 'yoga_breathwork');
    expect(normalizeTag('Nutritionist / Dietician'), 'nutritionist_dietician');
    expect(normalizeTag('  Flexibility / Yoga '), 'flexibility_yoga');
    expect(
        buildInterestTags([
          ['Yoga & Breathwork', 'General Fitness'],
          'Personal Trainer',
          null,
        ]),
        ['general_fitness', 'personal_trainer', 'yoga_breathwork']);
  });

  test('each person appears once, in the highest section that fits', () {
    final now = DateTime(2026, 9, 21);
    final feed = buildCategoryFeed(
      users: [
        _u('me'),
        _u('friend', followers: 5),
        _u('fan', followers: 1),
        _u('match', tags: ['yoga'], followers: 2),
        _u('star', followers: 900),
        _u('newbie', joined: now.subtract(const Duration(days: 3))),
        _u('nobody'),
        _u('coach', type: 'wellness'),
      ],
      currentUserId: 'me',
      followingIds: {'friend'},
      followerIds: {'friend', 'fan'},
      myTags: ['yoga'],
      myLocation: '',
      config: const SearchConfig(),
      now: now,
    );

    final guru = feed.sectionsFor('guru');
    List<String> ids(FeedSectionType t) =>
        guru.firstWhere((s) => s.type == t).users.map((u) => u.userId).toList();

    expect(ids(FeedSectionType.network), ['friend', 'fan']); // mutual first
    expect(ids(FeedSectionType.interest), ['match']);
    expect(ids(FeedSectionType.popular).first, 'star');
    final all = guru.expand((s) => s.users).map((u) => u.userId).toList();
    expect(all.toSet().length, all.length, reason: 'no duplicates');
    expect(all.contains('me'), isFalse);
    expect(feed.countFor('wellness'), 1);
    expect(feed.countFor('aspirant'), 0);
  });

  test('config controls order and can switch sections off', () {
    final cfg = SearchConfig.fromMap({
      'sectionOrder': ['popular', 'network'],
      'enabledSections': {'nearby': true},
      'titles': {'popular': 'Trending'},
    });
    expect(
        cfg.sectionOrder, [FeedSectionType.popular, FeedSectionType.network]);
    expect(cfg.disabled.contains(FeedSectionType.nearby), isFalse);
    expect(cfg.titleFor(FeedSectionType.popular), 'Trending');
    expect(SearchConfig.fromMap(null).disabled, {FeedSectionType.nearby});
  });

  test('nearby only when enabled and city matches', () {
    final feed = buildCategoryFeed(
      users: [
        _u('a', location: 'Lucknow, UP'),
        _u('b', location: 'Delhi'),
      ],
      currentUserId: 'me',
      followingIds: {},
      followerIds: {},
      myTags: [],
      myLocation: 'Lucknow, Uttar Pradesh',
      config: SearchConfig.fromMap({
        'sectionOrder': ['nearby', 'others'],
        'enabledSections': {'nearby': true},
      }),
    );
    final sections = feed.sectionsFor('guru');
    expect(sections.first.type, FeedSectionType.nearby);
    expect(sections.first.users.map((u) => u.userId), ['a']);
    expect(sections.last.users.map((u) => u.userId), ['b']);
  });

  test('every built-in subcategory has something to match on', () {
    for (final c in kAllCategories) {
      for (final s in c.subcategorySpecs) {
        expect(s.matchTags, isNotEmpty, reason: '${c.name} / ${s.displayName}');
        expect(s.matchTags.length, lessThanOrEqualTo(30));
      }
    }
  });
}
