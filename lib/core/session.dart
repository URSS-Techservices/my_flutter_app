/// Derived app session. Login method is not stored here — only uid + type.
enum SessionStatus {
  loading,
  loggedOut,
  needsAccountType,
  ready,
}

class Session {
  final SessionStatus status;
  final String? uid;
  final String? accountType;

  const Session({
    required this.status,
    this.uid,
    this.accountType,
  });

  const Session.loading() : this(status: SessionStatus.loading);
  const Session.loggedOut() : this(status: SessionStatus.loggedOut);

  bool get isReady => status == SessionStatus.ready;
}
