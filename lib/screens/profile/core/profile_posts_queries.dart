import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:halo/screens/profile/widgets/common/profile_post_image_url.dart';

/// Shared post sorting / query helpers for profile screens (no UI).
abstract final class ProfilePostsQueries {
  ProfilePostsQueries._();

  /// Same ordering rules as aspirant grid + wellness preview (`timestamp` / `createdAt`).
  static int compareFirestorePostTimestampsDesc(
    dynamic aTs,
    dynamic bTs,
  ) {
    if (aTs == null) return 1;
    if (bTs == null) return -1;
    if (aTs is Timestamp && bTs is Timestamp) return bTs.compareTo(aTs);
    return 0;
  }

  /// Sort `List<Map>` that carry merged `timestamp` (see wellness `_loadPosts`).
  static void sortPostPreviewMapsByTimestampDesc(
    List<Map<String, dynamic>> list,
  ) {
    list.sort(
      (a, b) => compareFirestorePostTimestampsDesc(
        a['timestamp'],
        b['timestamp'],
      ),
    );
  }

  /// Sort query docs like [AspirantRecentPostsGrid] (timestamp ?? createdAt).
  static int comparePostDocumentsByTimeDesc(
    QueryDocumentSnapshot<Map<String, dynamic>> a,
    QueryDocumentSnapshot<Map<String, dynamic>> b,
  ) {
    final aData = a.data();
    final bData = b.data();
    final aTs = aData['timestamp'] ?? aData['createdAt'];
    final bTs = bData['timestamp'] ?? bData['createdAt'];
    return compareFirestorePostTimestampsDesc(aTs, bTs);
  }

  /// Wellness profile: `posts` where `userId`, limit 30, sort in memory (existing behavior).
  static Future<List<Map<String, dynamic>>> fetchWellnessProfilePostsPreview({
    required FirebaseFirestore firestore,
    required String profileUserId,
  }) async {
    try {
      final snapshot = await firestore
          .collection('posts')
          .where('userId', isEqualTo: profileUserId)
          .limit(30)
          .get();

      final list = snapshot.docs.map((doc) {
        final d = doc.data();
        return {
          'id': doc.id,
          'imageUrl': profilePostImageUrlFromMap(d),
          'caption': d['caption'] ?? '',
          'timestamp': d['timestamp'] ?? d['createdAt'],
        };
      }).toList();

      sortPostPreviewMapsByTimestampDesc(list);
      return list;
    } catch (e) {
      debugPrint('Error loading posts: $e');
      return [];
    }
  }

  /// Guru profile: timestamp → createdAt → unordered fallback; limit 9 (existing behavior).
  static Future<List<Map<String, dynamic>>> fetchGuruProfilePostsPreview({
    required FirebaseFirestore firestore,
    required String profileUserId,
  }) async {
    try {
      QuerySnapshot<Map<String, dynamic>> postsSnapshot;
      try {
        postsSnapshot = await firestore
            .collection('posts')
            .where('userId', isEqualTo: profileUserId)
            .orderBy('timestamp', descending: true)
            .limit(9)
            .get();
      } catch (_) {
        try {
          postsSnapshot = await firestore
              .collection('posts')
              .where('userId', isEqualTo: profileUserId)
              .orderBy('createdAt', descending: true)
              .limit(9)
              .get();
        } catch (_) {
          postsSnapshot = await firestore
              .collection('posts')
              .where('userId', isEqualTo: profileUserId)
              .limit(9)
              .get();
        }
      }

      return postsSnapshot.docs.map((doc) {
        final d = doc.data() as Map<String, dynamic>;
        return <String, dynamic>{
          'id': doc.id,
          'imageUrl': d['imageUrl'] ?? '',
          'caption': d['caption'] ?? '',
          'timestamp': d['timestamp'] ?? d['createdAt'],
        };
      }).toList();
    } catch (e) {
      debugPrint('Error loading posts: $e');
      return [];
    }
  }
}
