import 'package:cloud_firestore/cloud_firestore.dart';

class SearchUsersResult {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final bool usedPrefix;
  SearchUsersResult({required this.docs, required this.usedPrefix});
}

class SearchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const int _userLimit = 80;
  static const int _postLimit = 80;

  /// Returns raw user docs and whether prefix query was used.
  Future<SearchUsersResult> searchUsers(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return SearchUsersResult(docs: [], usedPrefix: false);

    try {
      final snapshot = await _firestore
          .collection('users')
          .orderBy('searchTerms')
          .startAt([q])
          .endAt([q + '\uf8ff'])
          .limit(_userLimit)
          .get();
      if (snapshot.docs.isNotEmpty) {
        return SearchUsersResult(
          docs: snapshot.docs.cast<QueryDocumentSnapshot<Map<String, dynamic>>>(),
          usedPrefix: true,
        );
      }
    } catch (_) {}

    final snapshot = await _firestore.collection('users').limit(100).get();
    return SearchUsersResult(
      docs: snapshot.docs.cast<QueryDocumentSnapshot<Map<String, dynamic>>>(),
      usedPrefix: false,
    );
  }

  /// Returns raw post docs (recent first) for client-side ranking.
  /// Firestore has no full-text search; caption/tag filtering is done when ranking.
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> searchPosts(
    String query,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .limit(_postLimit)
          .get();
      return snapshot.docs.cast<QueryDocumentSnapshot<Map<String, dynamic>>>();
    } catch (_) {
      return [];
    }
  }

  /// Fetches relationship scores from current user to given user ids.
  /// Returns map of targetUserId -> score (0..1). Missing pairs default to 0.
  Future<Map<String, double>> getRelationshipScores(
    String currentUserId,
    List<String> targetUserIds,
  ) async {
    if (currentUserId.isEmpty || targetUserIds.isEmpty) return {};

    final Map<String, double> out = {};
    const batchSize = 10;
    for (var i = 0; i < targetUserIds.length; i += batchSize) {
      final batch = targetUserIds
          .skip(i)
          .take(batchSize)
          .toList();
      try {
        final snap = await _firestore
            .collection('relationships')
            .where('fromUserId', isEqualTo: currentUserId)
            .where('toUserId', whereIn: batch)
            .get();
        for (final doc in snap.docs) {
          final to = doc.data()['toUserId'] as String?;
          final score = (doc.data()['score'] as num?)?.toDouble();
          if (to != null && score != null) out[to] = score.clamp(0.0, 1.0);
        }
      } catch (_) {}
    }
    return out;
  }
}
