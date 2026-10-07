import 'package:cloud_firestore/cloud_firestore.dart';

/// Manages post save/bookmark state in Firestore.
/// - users/{userId}.savedPosts: { postId: true }
/// - posts/{postId}.savesCount: int (kept non-negative in transaction)
class SaveService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Toggles save state for the given user and post. Uses a transaction so
  /// user savedPosts and post savesCount stay in sync; prevents negative savesCount.
  Future<void> toggleSavePost({
    required String userId,
    required String postId,
  }) async {
    if (userId.isEmpty || postId.isEmpty) return;

    final userRef = _firestore.collection('users').doc(userId);
    final postRef = _firestore.collection('posts').doc(postId);

    await _firestore.runTransaction((Transaction tx) async {
      final userSnap = await tx.get(userRef);
      final postSnap = await tx.get(postRef);

      if (!userSnap.exists) return;
      if (!postSnap.exists) return;

      final savedPosts =
          Map<String, dynamic>.from(userSnap.data()?['savedPosts'] ?? {});
      final isSaved = savedPosts[postId] == true;
      final currentCount = (postSnap.data()?['savesCount'] as num?)?.toInt() ?? 0;

      if (isSaved) {
        savedPosts.remove(postId);
        tx.update(userRef, {'savedPosts': savedPosts});
        if (currentCount > 0) {
          tx.update(postRef, {'savesCount': FieldValue.increment(-1)});
        }
      } else {
        savedPosts[postId] = true;
        tx.update(userRef, {'savedPosts': savedPosts});
        tx.update(postRef, {'savesCount': FieldValue.increment(1)});
      }
    });
  }

  /// Returns the list of post IDs the user has saved (from user doc).
  Future<List<String>> getSavedPostIds(String userId) async {
    if (userId.isEmpty) return [];
    try {
      final snap = await _firestore.collection('users').doc(userId).get();
      final saved = snap.data()?['savedPosts'];
      if (saved is! Map) return [];
      return (saved as Map).keys.map((k) => k.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  /// Stream of the user's savedPosts map (postId -> true). Use for real-time UI.
  Stream<Map<String, dynamic>> savedPostsStream(String userId) {
    if (userId.isEmpty) return Stream.value({});
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snap) {
      final saved = snap.data()?['savedPosts'];
      if (saved is Map) return Map<String, dynamic>.from(saved);
      return <String, dynamic>{};
    });
  }
}
