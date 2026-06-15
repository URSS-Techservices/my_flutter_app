/// Logical profile flavor for HALO (maps from Firestore `accountType`).
enum ProfileKind {
  aspirant,
  guru,
  wellness,
}

ProfileKind profileKindFromAccountType(String? raw) {
  final t = (raw ?? 'aspirant').toString().toLowerCase().trim();
  if (t == 'guru') return ProfileKind.guru;
  if (t == 'wellness') return ProfileKind.wellness;
  return ProfileKind.aspirant;
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
