import 'package:cloud_firestore/cloud_firestore.dart';

/// Writes the signed-in user's presence to `users/{uid}`:
/// `isOnline` and `lastSeen` (also read by chat screens).
class PresenceRepository {
  PresenceRepository(this._firestore);

  final FirebaseFirestore _firestore;

  Future<void> setOnline(String userId, {required bool online}) {
    return _firestore.collection('users').doc(userId).set({
      'isOnline': online,
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
