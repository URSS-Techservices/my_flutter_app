import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewModel {
  final String id;
  final String reviewerId;
  final String text;
  final double rating;
  final DateTime? createdAt;

  const ReviewModel({
    required this.id,
    required this.reviewerId,
    required this.text,
    required this.rating,
    required this.createdAt,
  });

  factory ReviewModel.fromMap(String id, Map<String, dynamic> map) {
    return ReviewModel(
      id: id,
      reviewerId: (map['reviewerId'] ?? map['userId'] ?? '').toString(),
      text: (map['review'] ?? map['text'] ?? '').toString(),
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'reviewerId': reviewerId,
      'text': text,
      'rating': rating,
      'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
    };
  }
}
