import 'package:cloud_firestore/cloud_firestore.dart';

class FollowService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<bool> isFollowing({
    required String currentUserId,
    required String profileUserId,
  }) async {
    final doc = await _firestore
        .collection('users')
        .doc(profileUserId)
        .collection('followers')
        .doc(currentUserId)
        .get();
    return doc.exists;
  }

  Future<void> setFollowState({
    required String currentUserId,
    required String profileUserId,
    required bool shouldFollow,
  }) async {
    final followersDocRef = _firestore
        .collection('users')
        .doc(profileUserId)
        .collection('followers')
        .doc(currentUserId);
    final followingDocRef = _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('following')
        .doc(profileUserId);
    final profileUserRef = _firestore.collection('users').doc(profileUserId);
    final currentUserRef = _firestore.collection('users').doc(currentUserId);

    await _firestore.runTransaction((tx) async {
      if (shouldFollow) {
        tx.set(followersDocRef, {
          'followerId': currentUserId,
          'createdAt': FieldValue.serverTimestamp(),
        });
        tx.set(followingDocRef, {
          'followingId': profileUserId,
          'createdAt': FieldValue.serverTimestamp(),
        });
        tx.update(profileUserRef, {'followersCount': FieldValue.increment(1)});
        tx.update(currentUserRef, {'followingCount': FieldValue.increment(1)});
      } else {
        tx.delete(followersDocRef);
        tx.delete(followingDocRef);
        tx.update(profileUserRef, {'followersCount': FieldValue.increment(-1)});
        tx.update(currentUserRef, {'followingCount': FieldValue.increment(-1)});
      }
    });
  }
}
