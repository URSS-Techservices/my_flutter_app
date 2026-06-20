import 'package:cloud_firestore/cloud_firestore.dart';

/// Saves guru/wellness profiles to an aspirant's "My Circle" bookmark list.
class ProfileCircleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _savedRef(String userId) {
    return _firestore.collection('users').doc(userId).collection('savedProfiles');
  }

  Stream<List<Map<String, dynamic>>> savedProfilesStream(String userId) {
    if (userId.isEmpty) return Stream.value(const []);
    return _savedRef(userId)
        .orderBy('savedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => {...d.data(), 'id': d.id}).toList());
  }

  Stream<bool> isSavedStream({
    required String userId,
    required String profileUserId,
  }) {
    if (userId.isEmpty || profileUserId.isEmpty) return Stream.value(false);
    return _savedRef(userId).doc(profileUserId).snapshots().map((d) => d.exists);
  }

  Future<bool> isSaved({
    required String userId,
    required String profileUserId,
  }) async {
    if (userId.isEmpty || profileUserId.isEmpty) return false;
    final doc = await _savedRef(userId).doc(profileUserId).get();
    return doc.exists;
  }

  Future<void> toggleSaved({
    required String userId,
    required String profileUserId,
    required String accountType,
    required String displayName,
    String? profilePhoto,
    String? category,
  }) async {
    if (userId.isEmpty || profileUserId.isEmpty || userId == profileUserId) return;

    final ref = _savedRef(userId).doc(profileUserId);
    final existing = await ref.get();
    if (existing.exists) {
      await ref.delete();
      return;
    }

    await ref.set({
      'profileUserId': profileUserId,
      'accountType': accountType,
      'displayName': displayName,
      'profilePhoto': profilePhoto,
      'category': category,
      'savedAt': FieldValue.serverTimestamp(),
    });
  }
}
