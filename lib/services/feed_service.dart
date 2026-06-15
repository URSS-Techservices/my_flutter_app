import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:halo/utils/feed_ranking.dart';

class FeedService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const Duration _kRelationshipCacheTtl = Duration(minutes: 5);
  static final Map<String, _TimedScoreCache> _relationshipCache = {};

  // 🔹 Fetch recent posts
  Stream<QuerySnapshot<Map<String, dynamic>>> getRecentPosts() {
    return _firestore
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  // 🔹 MAIN FEED STREAM (FIXED)
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> getRankedFeedStream({
    required String currentUserId,
    String userPreference = '',
    bool followingOnly = false,
  }) {
    return getRecentPosts().asyncMap((snapshot) async {
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
          snapshot.docs;

      // ✅ APPLY FOLLOWING FILTER
      if (followingOnly && currentUserId.isNotEmpty) {
        final followingIds = await getFollowingIds(currentUserId);

        if (followingIds.isNotEmpty) {
          docs = docs
              .where((d) =>
              followingIds.contains((d.data()['userId'] ?? '')))
              .toList();
        } else {
          return [];
        }
      }

      // ✅ RANK POSTS
      return await rankPosts(
        docs: docs,
        currentUserId: currentUserId,
        userPreference: userPreference,
      );
    });
  }

  Future<({
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    QueryDocumentSnapshot<Map<String, dynamic>>? lastDoc,
    bool hasMore,
  })> getRankedFeedPage({
    required String currentUserId,
    String userPreference = '',
    bool followingOnly = false,
    int limit = 12,
    QueryDocumentSnapshot<Map<String, dynamic>>? startAfterDoc,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (startAfterDoc != null) {
      query = query.startAfterDocument(startAfterDoc);
    }

    final snapshot = await query.get();
    var docs = snapshot.docs;

    if (followingOnly && currentUserId.isNotEmpty) {
      final followingIds = await getFollowingIds(currentUserId);
      if (followingIds.isEmpty) {
        return (
          docs: const <QueryDocumentSnapshot<Map<String, dynamic>>>[],
          lastDoc: null,
          hasMore: false,
        );
      }
      docs = docs
          .where((d) => followingIds.contains((d.data()['userId'] ?? '')))
          .toList();
    }

    final ranked = await rankPosts(
      docs: docs,
      currentUserId: currentUserId,
      userPreference: userPreference,
    );

    return (
      docs: ranked,
      lastDoc: snapshot.docs.isNotEmpty ? snapshot.docs.last : startAfterDoc,
      hasMore: snapshot.docs.length >= limit,
    );
  }

  /// 🔹 UNDated pagination: createdAt is null
  Future<({
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    QueryDocumentSnapshot<Map<String, dynamic>>? lastDoc,
    bool hasMore,
  })> getRankedUndatedFeedPage({
    required String currentUserId,
    String userPreference = '',
    bool followingOnly = false,
    int limit = 12,
    QueryDocumentSnapshot<Map<String, dynamic>>? startAfterDoc,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection('posts')
        .where('createdAt', isNull: true)
        .orderBy(FieldPath.documentId)
        .limit(limit);

    if (startAfterDoc != null) {
      query = query.startAfterDocument(startAfterDoc);
    }

    final snapshot = await query.get();
    var docs = snapshot.docs;

    if (followingOnly && currentUserId.isNotEmpty) {
      final followingIds = await getFollowingIds(currentUserId);
      if (followingIds.isEmpty) {
        return (
          docs: const <QueryDocumentSnapshot<Map<String, dynamic>>>[],
          lastDoc: null,
          hasMore: false,
        );
      }
      docs = docs
          .where((d) => followingIds.contains((d.data()['userId'] ?? '')))
          .toList();
    }

    final ranked = await rankPosts(
      docs: docs,
      currentUserId: currentUserId,
      userPreference: userPreference,
    );

    return (
      docs: ranked,
      lastDoc: snapshot.docs.isNotEmpty ? snapshot.docs.last : startAfterDoc,
      hasMore: snapshot.docs.length >= limit,
    );
  }

  // 🔹 GET FOLLOWING USERS
  Future<List<String>> getFollowingIds(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('following')
          .get();

      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (_) {
      return [];
    }
  }

  // 🔹 RELATIONSHIP SCORES
  Future<Map<String, double>> getRelationshipScores(
      String currentUserId,
      List<String> postUserIds,
      ) async {
    if (currentUserId.isEmpty) return {};

    final unique = postUserIds.where((id) => id.isNotEmpty).toSet().toList();
    final map = <String, double>{};
    final missing = <String>[];

    for (final otherId in unique) {
      if (otherId == currentUserId) {
        map[otherId] = 1.0;
        continue;
      }

      final cacheKey = '${currentUserId}_$otherId';
      final cached = _relationshipCache[cacheKey];

      if (cached != null && !cached.isExpired) {
        map[otherId] = cached.score;
      } else {
        missing.add(otherId);
      }
    }

    for (final otherId in missing) {
      final docId = '${currentUserId}_$otherId';
      try {
        final doc =
        await _firestore.collection('relationships').doc(docId).get();

        final score =
        ((doc.data()?['score'] as num?)?.toDouble() ?? 0.0)
            .clamp(0.0, 1.0);

        map[otherId] = score;
        _relationshipCache[docId] = _TimedScoreCache(score);
      } catch (_) {
        map[otherId] = 0.0;
      }
    }

    return map;
  }

  // 🔹 RANKING LOGIC (FIXED)
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> rankPosts({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    required String currentUserId,
    required String userPreference,
  }) async {
    if (docs.isEmpty) return [];

    final userIds = docs
        .map((d) => (d.data()['userId'] as String?) ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final relScores = await getRelationshipScores(currentUserId, userIds);

    final scored = <_ScoredDoc>[];

    for (final doc in docs) {
      final data = doc.data();

      final dt = _safeCreatedAt(data['createdAt']);

      final userId = (data['userId'] as String?) ?? '';

      // Handle mixed numeric types from Firestore (int/double/string).
      final likes = _toInt(data['likeCount']);
      final comments = _toInt(data['commentCount']);
      final saves = _toInt(data['saveCount']);

      final type = (data['type'] as String?) ?? _inferPostType(data);

      final score = feedScore(
        createdAt: dt,
        relationshipScore: relScores[userId] ?? 0.0,
        likes: likes,
        comments: comments,
        saves: saves,
        postType: type,
        userPreference: userPreference,
      );

      scored.add(_ScoredDoc(doc: doc, score: score));
    }

    // ✅ STABLE SORT (NO 1-POST BUG)
    scored.sort((a, b) {
      final cmp = b.score.compareTo(a.score);
      if (cmp != 0) return cmp;

      final aTime =
          (a.doc.data()['createdAt'] as Timestamp?)?.toDate() ??
              DateTime.now();
      final bTime =
          (b.doc.data()['createdAt'] as Timestamp?)?.toDate() ??
              DateTime.now();

      return bTime.compareTo(aTime);
    });

    return scored.map((e) => e.doc).toList();
  }

  // 🔹 POST TYPE DETECTION
  String _inferPostType(Map<String, dynamic> data) {
    final type = (data['type'] as String?)?.toLowerCase();

    if (type == 'video') return 'video';
    if (type == 'image') return 'image';

    final media = data['media'] as List?;
    if (media != null && media.isNotEmpty) {
      final first = media.first;
      if (first is Map &&
          (first['type'] ?? '').toString().toLowerCase() == 'video') {
        return 'video';
      }
    }

    return 'image';
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? 0;
    return 0;
  }

  DateTime _safeCreatedAt(dynamic createdAt) {
    if (createdAt is Timestamp) return createdAt.toDate();
    if (createdAt is DateTime) return createdAt;
    if (createdAt is String) {
      final parsed = DateTime.tryParse(createdAt);
      if (parsed != null) return parsed;
    }
    // Missing/invalid timestamp should not be treated as "newest now".
    return DateTime.now().subtract(const Duration(days: 365));
  }
}

// 🔹 HELPER CLASSES
class _ScoredDoc {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final double score;

  _ScoredDoc({required this.doc, required this.score});
}

class _TimedScoreCache {
  final double score;
  final DateTime fetchedAt;

  _TimedScoreCache(this.score) : fetchedAt = DateTime.now();

  bool get isExpired =>
      DateTime.now().difference(fetchedAt) >
          FeedService._kRelationshipCacheTtl;
}