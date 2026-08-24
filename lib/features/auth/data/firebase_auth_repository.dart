import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:halo/core/session.dart';
import 'package:halo/features/auth/domain/auth_repository.dart';
import 'package:halo/features/auth/domain/session_mapper.dart';
import 'package:halo/screens/profile/core/profile_type.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  @override
  Stream<Session> watchSession() {
    return _auth.authStateChanges().asyncExpand((user) {
      if (user == null) {
        return Stream.value(const Session.loggedOut());
      }
      return _firestore.collection('users').doc(user.uid).snapshots().map(
            (snap) => sessionFromUserDoc(user.uid, snap.data()),
          );
    });
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> setAccountType(ProfileKind kind) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('Not signed in');
    }
    final type = accountTypeString(kind);
    final categoryLabel = type[0].toUpperCase() + type.substring(1);
    return _firestore.collection('users').doc(uid).set(
      {
        'uid': uid,
        'accountType': type,
        'category': categoryLabel,
        'profileType': type,
      },
      SetOptions(merge: true),
    );
  }
}
