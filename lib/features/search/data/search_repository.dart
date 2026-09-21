import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:halo/features/search/data/search_local.dart';
import 'package:halo/features/search/data/search_remote.dart';
import 'package:halo/features/search/domain/category_feed.dart';
import 'package:halo/features/search/domain/interest_tags.dart';
import 'package:halo/features/search/domain/search_contract.dart';
import 'package:halo/features/search/domain/search_models.dart';
import 'package:halo/utils/search_ranking.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SEARCH REPOSITORY (implements SearchContract)
// Wires remote (Firestore) + local (SharedPreferences) + ranking utils.
// This is the only class that knows about both layers simultaneously.
// ─────────────────────────────────────────────────────────────────────────────

class SearchRepository implements SearchContract {
  final SearchRemote _remote;
  final SearchLocal _local;

  SearchRepository({
    SearchRemote? remote,
    SearchLocal? local,
  })  : _remote = remote ?? SearchRemote(),
        _local = local ?? SearchLocal();

  // ── USER SEARCH ──────────────────────────────────────────────────────────

  @override
  Future<SearchUsersOutcome> searchUsers(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      return const SearchUsersOutcome(users: [], usedFallback: false);
    }

    final (:docs, :usedPrefix) = await _remote.fetchUsers(q);
    final currentUserId = _remote.currentUserId ?? '';
    final userIds = docs.map((d) => d.id).toList();
    final relScores =
        await _remote.fetchRelationshipScores(currentUserId, userIds);

    final scored = <({UserResult user, double score})>[];
    for (final doc in docs) {
      final data = doc.data();
      final username = safeStr(data['username']);
      final name = safeStr(data['name']).isNotEmpty
          ? safeStr(data['name'])
          : safeStr(data['full_name']).isNotEmpty
              ? safeStr(data['full_name'])
              : safeStr(data['business_name']);
      final bio = safeStr(data['bio']);
      final lastActiveAt =
          (data['lastActiveAt'] as Timestamp?)?.toDate() ?? DateTime.now();
      final followersCount = (data['followersCount'] as int?) ?? 0;
      final rel = relScores[doc.id] ?? 0.0;

      final score = userSearchScore(
        username: username,
        name: name,
        bio: bio,
        relationshipScore: rel,
        followersCount: followersCount,
        lastActiveAt: lastActiveAt,
        query: q,
      );

      final profilePhoto = safeStr(data['profilePhoto'] ??
          data['photoURL'] ??
          data['profile_photo'] ??
          data['avatar']);

      scored.add((
        user: UserResult(
          userId: doc.id,
          name: name.isNotEmpty ? name : 'Unnamed User',
          username: username,
          profilePhoto: profilePhoto.isEmpty ? null : profilePhoto,
          accountType: safeStr(data['accountType']).toLowerCase().isNotEmpty
              ? safeStr(data['accountType']).toLowerCase()
              : 'aspirant',
        ),
        score: score,
      ));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));

    return SearchUsersOutcome(
      users: scored.map((e) => e.user).toList(),
      usedFallback: !usedPrefix,
    );
  }

  // ── POST SEARCH ───────────────────────────────────────────────────────────

  @override
  Future<List<PostResult>> searchPosts(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    final docs = await _remote.fetchPosts(q);
    final scored = <({PostResult post, double score})>[];

    for (final doc in docs) {
      final data = doc.data();
      final caption = safeStr(data['caption']);
      final tags = safeStrList(data['tags']);
      final likes = (data['likesCount'] as int?) ?? 0;
      final comments = (data['commentsCount'] as int?) ?? 0;
      final saves = (data['savesCount'] as int?) ?? 0;
      final createdAt =
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

      final score = postSearchScore(
        caption: caption,
        tags: tags,
        likes: likes,
        comments: comments,
        saves: saves,
        createdAt: createdAt,
        query: q,
      );

      scored.add((
        post: PostResult(
          postId: doc.id,
          imageUrl: postImageUrl(data),
          caption: caption,
        ),
        score: score,
      ));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.map((e) => e.post).toList();
  }

  // ── CAROUSEL BANNERS ─────────────────────────────────────────────────────

  @override
  Stream<List<CarouselBanner>> getBanners() {
    return _remote.streamBanners().map((rawList) => rawList
        .map((data) => CarouselBanner.fromMap(data['id'] as String, data))
        .where((b) => b.imageUrl.isNotEmpty && b.isCurrentlyValid)
        .toList());
  }

  // ── CATEGORY EXPERTS ─────────────────────────────────────────────────────

  @override
  Future<List<UserResult>> getUsersByCategory({
    String? interestTerm,
    String? specializationTerm,
  }) async {
    final docs = await _remote.fetchUsersByCategory(
      interestTerm: interestTerm,
      specializationTerm: specializationTerm,
    );

    return docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final name = safeStr(data['name']).isNotEmpty
          ? safeStr(data['name'])
          : safeStr(data['full_name']).isNotEmpty
              ? safeStr(data['full_name'])
              : safeStr(data['business_name']).isNotEmpty
                  ? safeStr(data['business_name'])
                  : 'Unnamed';
      final profilePhoto = safeStr(data['profilePhoto'] ??
          data['photoURL'] ??
          data['profile_photo'] ??
          data['avatar']);

      return UserResult(
        userId: doc.id,
        name: name,
        username: safeStr(data['username']),
        profilePhoto: profilePhoto.isEmpty ? null : profilePhoto,
        accountType: safeStr(data['accountType']).toLowerCase().isNotEmpty
            ? safeStr(data['accountType']).toLowerCase()
            : 'aspirant',
      );
    }).toList();
  }

  // ── CATEGORIES + CONFIG ──────────────────────────────────────────────────

  @override
  Future<List<WellnessCategory>> getCategories() async {
    final docs = await _remote.fetchCategoryDocs();
    final categories = <WellnessCategory>[];
    for (var i = 0; i < docs.length; i++) {
      final category = WellnessCategory.fromMap(docs[i], i);
      if (category.subcategorySpecs.isNotEmpty) categories.add(category);
    }
    // Nothing (valid) in Firestore yet → built-in list keeps the app working.
    return categories.isEmpty ? kAllCategories : categories;
  }

  @override
  Future<SearchConfig> getSearchConfig() async =>
      SearchConfig.fromMap(await _remote.fetchSearchConfigDoc());

  // ── CATEGORY FEED ────────────────────────────────────────────────────────

  @override
  Future<CategoryFeed> getCategoryFeed(
    SubcategorySpec spec,
    SearchConfig config,
  ) async {
    final uid = _remote.currentUserId;

    // Start everything at once; nothing here depends on anything else.
    final tagged = _remote.fetchUsersByTags(spec.matchTags);
    final legacy = _remote.fetchUsersByCategory(
      interestTerm: spec.interestTerm,
      specializationTerm: spec.specializationTerm,
    );
    final following = uid == null
        ? Future.value(<String>{})
        : _remote.fetchFollowIds(uid, 'following');
    final followers = uid == null
        ? Future.value(<String>{})
        : _remote.fetchFollowIds(uid, 'followers');
    final me = uid == null
        ? Future.value(<String, dynamic>{})
        : _remote.fetchUserDoc(uid).then((d) => d ?? <String, dynamic>{});

    // `legacy` finds people who signed up before interestTags existed.
    final seen = <String>{};
    final docs = [...await tagged, ...await legacy]
        .where((d) => seen.add(d.id))
        .toList();

    final myData = await me;
    return buildCategoryFeed(
      users: docs.map((d) => _toFeedUser(d.id, d.data())).toList(),
      currentUserId: uid,
      followingIds: await following,
      followerIds: await followers,
      myTags: safeStrList(myData['interestTags']),
      myLocation: safeStr(myData['location']),
      config: config,
    );
  }

  static UserResult _toFeedUser(String id, Map<String, dynamic> data) {
    String firstNonEmpty(List<String> values, String fallback) =>
        values.firstWhere((v) => v.isNotEmpty, orElse: () => fallback);

    final photo = firstNonEmpty([
      safeStr(data['profilePhoto']),
      safeStr(data['photoURL']),
      safeStr(data['profile_photo']),
      safeStr(data['avatar']),
    ], '');
    final type = safeStr(data['accountType']).toLowerCase();

    DateTime? date(Object? v) => v is Timestamp ? v.toDate() : null;

    // Legacy docs may not have interestTags yet; derive them on the fly so the
    // interest ranking still works for those people.
    final storedTags = safeStrList(data['interestTags']);
    final tags = storedTags.isNotEmpty
        ? storedTags
        : buildInterestTags([
            data['areas_of_specialization'],
            data['profession'],
            data['facilities_services'],
            data['business_type'],
            data['fitness_goals'],
            data['interests'],
          ]);

    return UserResult(
      userId: id,
      name: firstNonEmpty([
        safeStr(data['name']),
        safeStr(data['full_name']),
        safeStr(data['business_name']),
      ], 'Unnamed User'),
      username: safeStr(data['username']),
      profilePhoto: photo.isEmpty ? null : photo,
      accountType: type.isNotEmpty ? type : 'aspirant',
      followersCount: (data['followersCount'] as num?)?.toInt() ?? 0,
      interestTags: tags,
      location: safeStr(data['location']),
      joinedAt: date(data['onboardingCompletedAt']) ??
          date(data['createdAt']) ??
          date(data['timestamp']),
      isFeatured: data['isFeatured'] == true,
      isVerified: data['isVerified'] == true,
    );
  }

  // ── RELATIONSHIP SCORES ───────────────────────────────────────────────────

  @override
  Future<Map<String, double>> getRelationshipScores(
    String currentUserId,
    List<String> targetUserIds,
  ) =>
      _remote.fetchRelationshipScores(currentUserId, targetUserIds);

  // ── RECENT SEARCHES ───────────────────────────────────────────────────────

  @override
  Future<List<String>> getRecentSearches() => _local.getRecentSearches();

  @override
  Future<void> saveRecentSearch(String term) => _local.saveSearch(term);

  @override
  Future<void> removeRecentSearch(String term) => _local.removeSearch(term);

  @override
  Future<void> clearRecentSearches() => _local.clearAll();
}
