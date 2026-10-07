import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:halo/models/post_model.dart';
import 'package:halo/models/user_model.dart';
import 'package:halo/screens/profile/core/profile_model.dart';
import 'package:halo/services/follow_service.dart';

class ProfileRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FollowService _followService = FollowService();

  Stream<UserModel?> watchUser(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return UserModel.fromMap(doc.id, doc.data()!);
    });
  }

  /// Raw `users/{id}` document stream — preserves all fields for legacy sections.
  Stream<Map<String, dynamic>?> watchUserDocument(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return doc.data();
    });
  }

  /// Unified model for new modular UI/controller layers.
  Stream<ProfileData?> watchProfileData(String userId) {
    return watchUserDocument(userId).map((data) {
      if (data == null) return null;
      return ProfileData.fromFirestore(userId, data);
    });
  }

  Future<bool> isFollowing({
    required String currentUserId,
    required String profileUserId,
  }) {
    return _followService.isFollowing(
      currentUserId: currentUserId,
      profileUserId: profileUserId,
    );
  }

  Future<void> applyFollowState({
    required String currentUserId,
    required String profileUserId,
    required bool shouldFollow,
  }) {
    return _followService.setFollowState(
      currentUserId: currentUserId,
      profileUserId: profileUserId,
      shouldFollow: shouldFollow,
    );
  }

  Future<List<PostModel>> fetchUserPosts({
    required String userId,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 18,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection('posts')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    final snap = await query.get();
    return snap.docs.map((d) => PostModel.fromMap(d.id, d.data())).toList();
  }
}
