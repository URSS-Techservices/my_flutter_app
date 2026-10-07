import 'package:cloud_firestore/cloud_firestore.dart';

/// Fields every profile type (aspirant, guru, wellness) shows in its header.
class ProfileBasics {
  final String id;
  final String accountType;
  final String name;
  final String username;
  final String tagline;
  final String bio;
  final String location;
  final String profilePhoto;
  final String coverPhoto;
  /// Raw presence: see `ActivityStatus` for what is shown.
  final bool isOnline;
  final DateTime? lastSeen;

  /// The user's privacy choice (default on). When off, nobody sees their
  /// status and they do not see anyone else's.
  final bool showActivityStatus;
  final int followersCount;
  final int followingCount;
  final int postsCount;
  final DateTime? joinedAt;

  const ProfileBasics({
    required this.id,
    required this.accountType,
    required this.name,
    required this.username,
    required this.tagline,
    required this.bio,
    required this.location,
    required this.profilePhoto,
    required this.coverPhoto,
    required this.isOnline,
    required this.lastSeen,
    required this.showActivityStatus,
    required this.followersCount,
    required this.followingCount,
    required this.postsCount,
    required this.joinedAt,
  });

  factory ProfileBasics.fromMap(String id, Map<String, dynamic> map) {
    return ProfileBasics(
      id: id,
      accountType: _text(map['accountType']).toLowerCase(),
      name: _text(map['name'] ?? map['full_name'] ?? map['business_name']),
      username: _text(map['username']),
      tagline: _text(map['tagline'] ?? map['fitnessTag']),
      bio: _text(map['bio']),
      location: _text(map['city'] ?? map['location']),
      profilePhoto: _text(map['profilePhoto'] ?? map['photoURL']),
      coverPhoto: _text(map['coverPhoto']),
      isOnline: map['isOnline'] == true,
      lastSeen: _date(map['lastSeen']),
      showActivityStatus: map['showActivityStatus'] != false,
      followersCount: _int(map['followersCount']),
      followingCount: _int(map['followingCount']),
      postsCount: _int(map['postsCount']),
      joinedAt: _date(map['createdAt']),
    );
  }
}

String _text(Object? value) => value == null ? '' : value.toString().trim();

/// Firestore numbers can come back as int or double; never cast with `as int`.
int _int(Object? value) => value is num ? value.toInt() : 0;

DateTime? _date(Object? value) => value is Timestamp ? value.toDate() : null;
