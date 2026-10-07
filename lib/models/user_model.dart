import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String username;
  final String name;
  final String bio;
  final String accountType;
  final String profilePhoto;
  final String coverPhoto;
  final int followersCount;
  final int followingCount;
  final int postsCount;
  final DateTime? lastActiveAt;

  const UserModel({
    required this.id,
    required this.username,
    required this.name,
    required this.bio,
    required this.accountType,
    required this.profilePhoto,
    required this.coverPhoto,
    required this.followersCount,
    required this.followingCount,
    required this.postsCount,
    required this.lastActiveAt,
  });

  factory UserModel.fromMap(String id, Map<String, dynamic> map) {
    final rawType = (map['accountType'] ?? map['category'] ?? map['profileType'] ?? 'aspirant')
        .toString()
        .toLowerCase();
    final normalizedType = (rawType == 'guru' || rawType == 'wellness')
        ? rawType
        : 'aspirant';
    return UserModel(
      id: id,
      username: (map['username'] ?? '').toString(),
      name: (map['name'] ?? map['full_name'] ?? map['business_name'] ?? '').toString(),
      bio: (map['bio'] ?? '').toString(),
      accountType: normalizedType,
      profilePhoto: (map['profilePhoto'] ?? map['photoURL'] ?? '').toString(),
      coverPhoto: (map['coverPhoto'] ?? '').toString(),
      followersCount: (map['followersCount'] as num?)?.toInt() ?? 0,
      followingCount: (map['followingCount'] as num?)?.toInt() ?? 0,
      postsCount: (map['postsCount'] as num?)?.toInt() ?? 0,
      lastActiveAt: (map['lastActiveAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'name': name,
      'bio': bio,
      'accountType': accountType,
      'profilePhoto': profilePhoto,
      'coverPhoto': coverPhoto,
      'followersCount': followersCount,
      'followingCount': followingCount,
      'postsCount': postsCount,
      'lastActiveAt': lastActiveAt == null ? null : Timestamp.fromDate(lastActiveAt!),
    };
  }
}
