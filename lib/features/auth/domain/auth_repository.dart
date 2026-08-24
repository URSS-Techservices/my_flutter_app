import 'package:halo/core/session.dart';
import 'package:halo/screens/profile/core/profile_type.dart';

/// Auth + user-doc contract. Firebase / Google APIs live only in the data
/// implementation — never in the UI.
abstract class AuthRepository {
  Stream<Session> watchSession();

  Future<void> signOut();

  /// Writes `accountType` on the existing uid. Never creates a second account.
  Future<void> setAccountType(ProfileKind kind);

  /// Sign in by username, email, or mobile number. Firestore lookup for the
  /// non-email identifiers happens in the data layer, not the UI.
  Future<void> signInWithEmailOrUsername({
    required String identifier,
    required String password,
  });

  /// Google sign-in flow. Creates the initial user doc on first login only.
  /// Completes silently if the user cancels the picker.
  Future<void> signInWithGoogle();
}
