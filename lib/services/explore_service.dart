import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:halo/utils/explore_ranking.dart';

class ExploreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const Duration _kSideQueryTtl = Duration(minutes: 3);
  static final Map<String, _TimedListCache> _followingCache = {};
  static final Map<String, _TimedListCache> _interestsCache = {};

  /// All posts ordered by createdAt descending, limit 200.
  /// No date filter — we want to show all existing content on Explore.
  Stream<QuerySnapshot<Map<String, dynamic>>> getRecentPosts() {
    return _firestore
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots();
  }

  /// User IDs that the current user follows.
  Future<List<String>> getFollowingIds(String currentUserId) async {
    if (currentUserId.isEmpty) return [];
    final cached = _followingCache[currentUserId];
    if (cached != null && !cached.isExpired) return cached.values;
    try {
      final snap = await _firestore
          .collection('follows')
          .where('followerId', isEqualTo: currentUserId)
          .get();
      final values = snap.docs
          .map((d) => (d.data()['followingId'] as String?) ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
      _followingCache[currentUserId] = _TimedListCache(values);
      return values;
    } catch (_) {
      return [];
    }
  }

  /// Current user's interests from user_interests collection.
  Future<List<String>> getUserInterests(String currentUserId) async {
    if (currentUserId.isEmpty) return [];
    final cached = _interestsCache[currentUserId];
    if (cached != null && !cached.isExpired) return cached.values;
    try {
      final snap = await _firestore
          .collection('user_interests')
          .where('userId', isEqualTo: currentUserId)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) {
        _interestsCache[currentUserId] = _TimedListCache(const []);
        return [];
      }
      final list = snap.docs.first.data()['interests'];
      if (list is! List) {
        _interestsCache[currentUserId] = _TimedListCache(const []);
        return [];
      }
      final values = list.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
      _interestsCache[currentUserId] = _TimedListCache(values);
      return values;
    } catch (_) {
      return [];
    }
  }

  /// Explore feed: ranked by exploreScore, diversity (max 3 per user).
  /// Shows ALL posts — not filtering by following so the grid is always full.
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> getExplorePostsStream(String currentUserId) {
    return getRecentPosts().asyncMap((snapshot) async {
      var docs = snapshot.docs;

      final userInterests = await getUserInterests(currentUserId);

      final scored = <_ScoredPost>[];
      for (final doc in docs) {
        final d = doc.data();
        final tags = (d['tags'] as List?)?.map((e) => e.toString()).where((s) => s.isNotEmpty).toList() ?? [];
        final createdAt = (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        final likes = (d['likesCount'] as int?) ?? 0;
        final comments = (d['commentsCount'] as int?) ?? 0;
        final saves = (d['savesCount'] as int?) ?? 0;
        final score = exploreScore(
          postTags: tags,
          userInterests: userInterests,
          likes: likes,
          comments: comments,
          saves: saves,
          createdAt: createdAt,
        );
        scored.add(_ScoredPost(doc: doc, score: score));
      }

      scored.sort((a, b) => b.score.compareTo(a.score));

      final perUserCount = <String, int>{};
      const maxPerUser = 3;
      final result = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      for (final s in scored) {
        final uid = (s.doc.data()['userId'] as String?) ?? '';
        if ((perUserCount[uid] ?? 0) >= maxPerUser) continue;
        perUserCount[uid] = (perUserCount[uid] ?? 0) + 1;
        result.add(s.doc);
      }

      return result;
    });
  }
}

class _TimedListCache {
  final List<String> values;
  final DateTime fetchedAt;

  _TimedListCache(List<String> source)
      : values = List.unmodifiable(source),
        fetchedAt = DateTime.now();

  bool get isExpired =>
      DateTime.now().difference(fetchedAt) > ExploreService._kSideQueryTtl;
}

class _ScoredPost {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final double score;
  _ScoredPost({required this.doc, required this.score});
}
