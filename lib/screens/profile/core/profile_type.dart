/// Logical profile flavor for HALO (maps from Firestore `accountType`).
enum ProfileKind {
  aspirant,
  guru,
  wellness,
}

ProfileKind profileKindFromAccountType(String? raw) {
  return tryProfileKindFromAccountType(raw) ?? ProfileKind.aspirant;
}

/// Null when the user has not chosen aspirant / guru / wellness yet.
ProfileKind? tryProfileKindFromAccountType(String? raw) {
  final t = (raw ?? '').toString().toLowerCase().trim();
  if (t.isEmpty) return null;
  if (t == 'guru') return ProfileKind.guru;
  if (t == 'wellness') return ProfileKind.wellness;
  if (t == 'aspirant') return ProfileKind.aspirant;
  return null;
}

String accountTypeString(ProfileKind kind) {
  switch (kind) {
    case ProfileKind.guru:
      return 'guru';
    case ProfileKind.wellness:
      return 'wellness';
    case ProfileKind.aspirant:
      return 'aspirant';
  }
}
