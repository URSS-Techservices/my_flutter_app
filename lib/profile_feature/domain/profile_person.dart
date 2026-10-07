/// A row in a Followers / Following list, or the other person in an
/// activity ("started following …").
class ProfilePerson {
  final String id;
  final String name;
  final String username;
  final String photoUrl;
  final String city;
  final String accountType;

  const ProfilePerson({
    required this.id,
    required this.name,
    required this.username,
    required this.photoUrl,
    this.city = '',
    this.accountType = '',
  });

  factory ProfilePerson.fromMap(String id, Map<String, dynamic> map) {
    String text(Object? v) => v == null ? '' : v.toString().trim();
    return ProfilePerson(
      id: id,
      name: text(map['name'] ?? map['full_name'] ?? map['business_name']),
      username: text(map['username']),
      photoUrl: text(map['profilePhoto'] ?? map['photoURL']),
      city: text(map['city'] ?? map['location']),
      accountType: text(map['accountType']).toLowerCase(),
    );
  }

  String get displayName =>
      name.isNotEmpty ? name : (username.isNotEmpty ? username : 'Halo user');
}

/// Someone this profile followed, and when.
class ProfileFollowEvent {
  final ProfilePerson person;
  final DateTime? at;

  const ProfileFollowEvent({required this.person, required this.at});
}
