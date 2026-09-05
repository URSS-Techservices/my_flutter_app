/// Derived app session. Login method is not stored here — the whole app routes
/// off [status]. Authentication (Firebase identity) and HALO onboarding are two
/// separate concepts, so a signed-in Firebase user can still be
/// [SessionStatus.emailVerificationRequired] or [SessionStatus.onboardingRequired].
enum SessionStatus {
  /// Firebase / Firestore streams are still resolving.
  loading,

  /// No Firebase user. Show the login page.
  loggedOut,

  /// Email/password user whose email is not verified yet.
  emailVerificationRequired,

  /// Authenticated (and verified where required) but HALO onboarding is not
  /// finished. Use [accountType] to tell the category step from the profile
  /// step: null means the 3-category page, non-null means resume the profile.
  onboardingRequired,

  /// Fully onboarded. Show Home.
  authenticated,
}

class Session {
  final SessionStatus status;
  final String? uid;
  final String? email;

  /// aspirant / guru / wellness once chosen, otherwise null.
  final String? accountType;

  /// Mirrors Firestore `onboardingCompleted` (legacy full profiles count too).
  final bool onboardingCompleted;

  const Session({
    required this.status,
    this.uid,
    this.email,
    this.accountType,
    this.onboardingCompleted = false,
  });

  const Session.loading() : this(status: SessionStatus.loading);
  const Session.loggedOut() : this(status: SessionStatus.loggedOut);

  bool get isAuthenticated => status == SessionStatus.authenticated;

  /// Onboarding started with no account type yet → show category selection.
  bool get needsCategorySelection =>
      status == SessionStatus.onboardingRequired && accountType == null;

  /// Account type chosen but profile not finished → resume profile onboarding.
  bool get needsProfileOnboarding =>
      status == SessionStatus.onboardingRequired && accountType != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Session &&
          status == other.status &&
          uid == other.uid &&
          email == other.email &&
          accountType == other.accountType &&
          onboardingCompleted == other.onboardingCompleted;

  @override
  int get hashCode =>
      Object.hash(status, uid, email, accountType, onboardingCompleted);
}
