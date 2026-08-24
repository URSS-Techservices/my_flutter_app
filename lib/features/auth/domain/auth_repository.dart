import 'package:firebase_auth/firebase_auth.dart';
import 'package:halo/screens/profile/core/profile_type.dart';

/// Auth + user-doc writes. Firebase lives in the data layer only.
abstract class AuthRepository {
  Stream<User?> authState();

  Future<void> signOut();

  /// Writes `accountType` on the existing uid. Never creates a second account.
  Future<void> setAccountType({
    required String uid,
    required ProfileKind kind,
  });
}
