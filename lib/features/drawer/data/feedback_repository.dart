import 'package:cloud_firestore/cloud_firestore.dart';

/// Writes "Rate & Feedback" to `feedback/{id}` (same collection the
/// Settings page uses; staff read it from the admin dashboard).
class FeedbackRepository {
  FeedbackRepository(this._firestore);

  final FirebaseFirestore _firestore;

  /// [stars] is 1–5, or null when the user only wrote a message.
  Future<void> send({
    required String userId,
    required int? stars,
    required String message,
  }) {
    return _firestore.collection('feedback').add({
      'userId': userId,
      'type': 'feedback',
      if (stars != null) 'rating': stars,
      'message': message,
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}
