import 'package:cloud_firestore/cloud_firestore.dart';

class StoryModel {
  final String id;
  final String userId;
  final String username;
  final String? userPhotoUrl;
  final String mediaUrl;
  final String mediaType;
  final DateTime createdAt;
  final List<String> viewers;

  StoryModel({
    required this.id,
    required this.userId,
    required this.username,
    this.userPhotoUrl,
    required this.mediaUrl,
    required this.mediaType,
    required this.createdAt,
    required this.viewers,
  });

  factory StoryModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;

    return StoryModel(
      id: doc.id,
      userId: data?['userId']?.toString() ?? '',
      username: data?['username']?.toString() ?? 'Unknown',
      userPhotoUrl: data?['userPhotoUrl'],
      mediaUrl: data?['mediaUrl']?.toString() ?? '',
      mediaType: data?['mediaType']?.toString() ?? 'image',
      createdAt:
      (data?['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      viewers: List<String>.from(data?['viewers'] ?? []),
    );
  }
}
