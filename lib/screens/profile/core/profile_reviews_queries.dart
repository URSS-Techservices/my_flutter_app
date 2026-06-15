import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Shared review fetch helpers for guru / wellness profiles (no UI).
abstract final class ProfileReviewsQueries {
  ProfileReviewsQueries._();

  /// Guru first-tab reviews: `guruId`, composite ordering, limit 2.
  static Future<List<Map<String, dynamic>>> fetchGuruProfileReviewsPreview({
    required FirebaseFirestore firestore,
    required String profileUserId,
  }) async {
    try {
      final reviewsSnapshot = await firestore
          .collection('reviews')
          .where('guruId', isEqualTo: profileUserId)
          .orderBy('createdAt', descending: true)
          .orderBy(FieldPath.documentId, descending: true)
          .limit(2)
          .get();

      if (reviewsSnapshot.docs.isEmpty) return [];

      return reviewsSnapshot.docs.map((doc) {
        final d = doc.data();
        return <String, dynamic>{
          'id': doc.id,
          'name': d['userName'] ?? d['name'] ?? 'User',
          'rating': d['rating'] ?? 5,
          'text': d['text'] ?? '',
          'createdAt': d['createdAt'],
          'profilePhoto': d['profilePhoto'],
        };
      }).toList();
    } catch (e) {
      debugPrint('Error loading reviews: $e');
      return [];
    }
  }

  /// Wellness reviews: prefer `orderBy(createdAt)`; fallback query without order.
  ///
  /// Returns `null` when both queries fail or an outer error occurs — caller
  /// should **not** overwrite existing `_reviews` (matches legacy wellness behavior).
  static Future<List<Map<String, dynamic>>?> fetchWellnessProfileReviewsOrSkip({
    required FirebaseFirestore firestore,
    required String profileUserId,
  }) async {
    try {
      QuerySnapshot<Map<String, dynamic>>? reviewsSnapshot;
      try {
        reviewsSnapshot = await firestore
            .collection('reviews')
            .where('wellnessId', isEqualTo: profileUserId)
            .orderBy('createdAt', descending: true)
            .limit(3)
            .get();
      } catch (_) {
        try {
          reviewsSnapshot = await firestore
              .collection('reviews')
              .where('wellnessId', isEqualTo: profileUserId)
              .limit(3)
              .get();
        } catch (_) {
          reviewsSnapshot = null;
        }
      }

      if (reviewsSnapshot != null) {
        return reviewsSnapshot.docs.map((doc) {
          final d = doc.data();
          return {
            'id': doc.id,
            'userName': d['userName'] ?? 'User',
            'rating': d['rating'] ?? 5,
            'text': d['text'] ?? '',
            'profilePhoto': d['profilePhoto'],
            'createdAt': d['createdAt'],
          };
        }).toList();
      }
      return null;
    } catch (e) {
      debugPrint('Error loading reviews: $e');
      return null;
    }
  }
}
