import 'package:halo/core/session.dart';
import 'package:halo/screens/profile/core/profile_type.dart';

/// Single source of truth for turning "Firebase user + Firestore doc" into a
/// [Session]. Authentication and onboarding are decided here, never scattered
/// across screens.
///
/// [requiresEmailVerification] is computed in the data layer (true only for a
/// password-provider user whose email is not yet verified). Provider logins
/// (Google / Apple / Phone) and OTP logins are inherently verified.
Session sessionFromUserDoc(
  String uid,
  Map<String, dynamic>? data, {
  String? email,
  bool requiresEmailVerification = false,
}) {
  if (requiresEmailVerification) {
    return Session(
      status: SessionStatus.emailVerificationRequired,
      uid: uid,
      email: email,
    );
  }

  final kind = _accountKind(data);
  final accountType = kind == null ? null : accountTypeString(kind);

  // A brand-new doc that only has an account type (chosen on the category
  // page) is NOT complete — a legacy doc additionally carries a real profile.
  final completed =
      data?['onboardingCompleted'] == true || _hasLegacyProfile(data, kind);

  if (completed) {
    return Session(
      status: SessionStatus.authenticated,
      uid: uid,
      email: email,
      accountType: accountType,
      onboardingCompleted: true,
    );
  }

  return Session(
    status: SessionStatus.onboardingRequired,
    uid: uid,
    email: email,
    accountType: accountType,
    onboardingCompleted: false,
  );
}

ProfileKind? _accountKind(Map<String, dynamic>? data) {
  if (data == null) return null;
  final raw = (data['accountType'] ?? data['category'] ?? data['profileType'])
      ?.toString();
  return tryProfileKindFromAccountType(raw);
}

/// Users onboarded before `onboardingCompleted` existed are recognised by an
/// account type plus a saved username, so they skip onboarding entirely.
bool _hasLegacyProfile(Map<String, dynamic>? data, ProfileKind? kind) {
  if (data == null || kind == null) return false;
  final username = (data['username'] ?? '').toString().trim();
  return username.isNotEmpty;
}
