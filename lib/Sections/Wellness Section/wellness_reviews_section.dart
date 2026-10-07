// wellness_reviews_section.dart
// VERIFIED REVIEWS & RATINGS SYSTEM

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:halo/core/halo_toast.dart';
class WellnessReviewsSection extends StatefulWidget {
  final String wellnessUserId;

  const WellnessReviewsSection({
    Key? key,
    required this.wellnessUserId,
  }) : super(key: key);

  @override
  State<WellnessReviewsSection> createState() =>
      _WellnessReviewsSectionState();
}

class _WellnessReviewsSectionState extends State<WellnessReviewsSection> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  int _selectedRating = 5;
  final TextEditingController _reviewCtrl = TextEditingController();

  Future<bool> _hasBooking() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final snap = await _firestore
        .collection('booking_requests')
        .where('wellnessId', isEqualTo: widget.wellnessUserId)
        .where('userId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'accepted')
        .limit(1)
        .get();

    return snap.docs.isNotEmpty;
  }

  Future<void> _submitReview() async {
    final user = _auth.currentUser;
    if (user == null || _reviewCtrl.text.isEmpty) return;

    final userDoc =
    await _firestore.collection('users').doc(user.uid).get();

    final userName = userDoc.data()?['name'] ?? 'User';

    await _firestore.collection('reviews').add({
      'wellnessId': widget.wellnessUserId,
      'userId': user.uid,
      'userName': userName,
      'rating': _selectedRating,
      'text': _reviewCtrl.text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    // ---------- UPDATE AVERAGE RATING ----------
    final reviewsSnap = await _firestore
        .collection('reviews')
        .where('wellnessId', isEqualTo: widget.wellnessUserId)
        .get();

    double total = 0;
    for (var d in reviewsSnap.docs) {
      total += (d['rating'] ?? 5).toDouble();
    }

    final avg =
    reviewsSnap.docs.isEmpty ? 5 : total / reviewsSnap.docs.length;

    await _firestore
        .collection('users')
        .doc(widget.wellnessUserId)
        .update({
      'rating': avg,
      'reviewCount': reviewsSnap.size,
    });

    _reviewCtrl.clear();
    setState(() => _selectedRating = 5);

    HaloToast.show('Review submitted');
  }

  Widget _buildReviewForm() {
    return FutureBuilder<bool>(
      future: _hasBooking(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == false) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Leave a Review',
                style:
                TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: List.generate(5, (i) {
                  return IconButton(
                    icon: Icon(
                      i < _selectedRating
                          ? Icons.star
                          : Icons.star_border,
                      color: Colors.amber,
                    ),
                    onPressed: () =>
                        setState(() => _selectedRating = i + 1),
                  );
                }),
              ),
              TextField(
                controller: _reviewCtrl,
                maxLines: 3,
                decoration:
                const InputDecoration(hintText: 'Write your review'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _submitReview,
                child: const Text('Submit Review'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Reviews & Ratings',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          // ---------- REVIEW FORM ----------
          _buildReviewForm(),

          // ---------- REVIEWS LIST ----------
          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('reviews')
                .where('wellnessId',
                isEqualTo: widget.wellnessUserId)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final docs = snapshot.data?.docs ?? [];

              if (docs.isEmpty) {
                return const Text(
                  'No reviews yet',
                  style: TextStyle(color: Colors.grey),
                );
              }

              return Column(
                children: docs.map((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final rating = data['rating'] ?? 5;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 6,
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['userName'] ?? 'User',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: List.generate(
                            5,
                                (i) => Icon(
                              i < rating
                                  ? Icons.star
                                  : Icons.star_border,
                              size: 16,
                              color: Colors.amber,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          data['text'] ?? '',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
