import 'package:halo/core/session.dart';
import 'package:halo/screens/profile/core/profile_type.dart';

/// Auth + user-doc writes. Firebase stays in the data layer.
abstract class AuthRepository {
  Stream<Session> watchSession();

  Future<void> signOut();

  /// Writes `accountType` on the existing uid. Never creates a second account.
  Future<void> setAccountType(ProfileKind kind);
}
