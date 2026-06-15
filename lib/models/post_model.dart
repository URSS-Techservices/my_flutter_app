import 'package:cloud_firestore/cloud_firestore.dart';

class PostModel {
  final String id;
  final String userId;
  final String caption;
  final List<String> tags;
  final String imageUrl;
  final int likesCount;
  final int commentsCount;
  final int savesCount;
  final DateTime? createdAt;

  const PostModel({
    required this.id,
    required this.userId,
    required this.caption,
    required this.tags,
    required this.imageUrl,
    required this.likesCount,
    required this.commentsCount,
    required this.savesCount,
    required this.createdAt,
  });

  factory PostModel.fromMap(String id, Map<String, dynamic> map) {
    final images = (map['images'] as List?)?.map((e) => e.toString()).toList() ?? const [];
    final media = (map['media'] as List?) ?? const [];
    String fallback = '';
    if (images.isNotEmpty) fallback = images.first;
    if (fallback.isEmpty && media.isNotEmpty && media.first is Map) {
      fallback = (media.first['url'] ?? '').toString();
    }
    return PostModel(
      id: id,
      userId: (map['userId'] ?? '').toString(),
      caption: (map['caption'] ?? '').toString(),
      tags: (map['tags'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      imageUrl: (map['imageUrl'] ?? fallback).toString(),
      likesCount: (map['likesCount'] as num?)?.toInt() ?? 0,
      commentsCount: (map['commentsCount'] as num?)?.toInt() ?? 0,
      savesCount: (map['savesCount'] as num?)?.toInt() ?? (map['saveCount'] as num?)?.toInt() ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'caption': caption,
      'tags': tags,
      'imageUrl': imageUrl,
      'likesCount': likesCount,
      'commentsCount': commentsCount,
      'savesCount': savesCount,
      'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
    };
  }
}
