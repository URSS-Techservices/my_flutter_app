import 'package:halo/core/session.dart';
import 'package:halo/features/auth/domain/phone_otp_session.dart';
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
  /// [password] is the account password, or a 6-digit email OTP.
  Future<void> signInWithEmailOrUsername({
    required String identifier,
    required String password,
  });

  /// Creates a new email/password account. Used by the sign-up flow before the
  /// user picks an account type. UI never talks to Firebase directly.
  Future<void> signUpWithEmail({
    required String email,
    required String password,
  });

  /// Emails a 6-digit login OTP to the account's email.
  Future<void> sendLoginOtp({required String identifier});

  /// Google sign-in flow. Creates the initial user doc on first login only.
  /// Completes silently if the user cancels the picker.
  Future<void> signInWithGoogle();

  /// Apple sign-in flow. Native on iOS, a browser hand-off on Android.
  /// Creates the initial user doc on first login only, and captures the name
  /// then because Apple discloses it exactly once.
  /// Completes silently if the user cancels.
  Future<void> signInWithApple();

  /// Sends an SMS code to [phoneNumber], which must be in E.164 form
  /// (for example `+919876543210`). Resolves once the code is on its way, or
  /// with [PhoneOtpSession.autoVerified] when Android signs in by itself.
  /// Pass [resendToken] from a previous session when resending.
  ///
  /// Android hands out a replacement verification id when SMS auto-retrieval
  /// gives up, and the old id stops working at that point. [onVerificationId]
  /// fires for every id, including that late one, so the caller must always
  /// verify against the most recent value.
  Future<PhoneOtpSession> sendPhoneOtp({
    required String phoneNumber,
    int? resendToken,
    void Function(String verificationId)? onVerificationId,
  });

  /// Completes phone sign-in with the code the user typed. Creates the initial
  /// user doc on first login only, without an accountType, so the gate routes
  /// new users to the account-type screen.
  Future<void> verifyPhoneOtp({
    required String verificationId,
    required String smsCode,
  });
}
