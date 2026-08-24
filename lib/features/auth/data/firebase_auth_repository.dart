import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:halo/features/auth/domain/auth_repository.dart';
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
  Stream<User?> authState() => _auth.authStateChanges();

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> setAccountType({
    required String uid,
    required ProfileKind kind,
  }) {
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
