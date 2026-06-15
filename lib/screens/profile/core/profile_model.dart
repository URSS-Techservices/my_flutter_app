import 'package:halo/screens/profile/core/profile_type.dart';

/// Unified profile snapshot for shared UI + controllers.
/// Type-specific Firestore fields remain in [extra] unchanged.
class ProfileData {
  final String id;
  final String name;
  final String username;
  final String bio;
  final String city;
  final int followersCount;
  final int followingCount;
  final int postsCount;
  final String profilePhoto;
  final String coverPhoto;
  final ProfileKind kind;
  /// Full Firestore document map (read-only snapshot for sections).
  final Map<String, dynamic> extra;

  const ProfileData({
    required this.id,
    required this.name,
    required this.username,
    required this.bio,
    required this.city,
    required this.followersCount,
    required this.followingCount,
    required this.postsCount,
    required this.profilePhoto,
    required this.coverPhoto,
    required this.kind,
    required this.extra,
  });

  factory ProfileData.fromFirestore(String id, Map<String, dynamic> data) {
    final kind = profileKindFromAccountType(data['accountType']?.toString());
    final name = (data['full_name'] ??
            data['name'] ??
            data['business_name'] ??
            '')
        .toString();
    final username = (data['username'] ?? '').toString();
    final bio = (data['bio'] ?? '').toString();
    final city = (data['city'] ?? data['location'] ?? '').toString();
    return ProfileData(
      id: id,
      name: name,
      username: username,
      bio: bio,
      city: city,
      followersCount: (data['followersCount'] as num?)?.toInt() ?? 0,
      followingCount: (data['followingCount'] as num?)?.toInt() ?? 0,
      postsCount: (data['postsCount'] as num?)?.toInt() ?? 0,
      profilePhoto: (data['profilePhoto'] ?? data['photoURL'] ?? '').toString(),
      coverPhoto: (data['coverPhoto'] ?? '').toString(),
      kind: kind,
      extra: Map<String, dynamic>.from(data),
    );
  }

  ProfileData copyWith({
    String? name,
    String? username,
    String? bio,
    String? city,
    int? followersCount,
    int? followingCount,
    int? postsCount,
    String? profilePhoto,
    String? coverPhoto,
    ProfileKind? kind,
    Map<String, dynamic>? extra,
  }) {
    return ProfileData(
      id: id,
      name: name ?? this.name,
      username: username ?? this.username,
      bio: bio ?? this.bio,
      city: city ?? this.city,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      postsCount: postsCount ?? this.postsCount,
      profilePhoto: profilePhoto ?? this.profilePhoto,
      coverPhoto: coverPhoto ?? this.coverPhoto,
      kind: kind ?? this.kind,
      extra: extra ?? Map<String, dynamic>.from(this.extra),
    );
  }
}
