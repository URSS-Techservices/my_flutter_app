/// Result of asking for a phone OTP. Deliberately free of Firebase types so
/// the UI and controller never import firebase_auth.
class PhoneOtpSession {
  const PhoneOtpSession({
    this.verificationId,
    this.resendToken,
    this.autoVerified = false,
  });

  /// Needed to build the credential when the user types the SMS code.
  final String? verificationId;

  /// Pass back on resend so Android does not restart the whole flow.
  final int? resendToken;

  /// Android can read the SMS itself and sign the user in with no code entry.
  /// When true the session is already live and the OTP step must be skipped.
  final bool autoVerified;
}
