// wellness_analytics_section.dart
// OWNER-ONLY ANALYTICS DASHBOARD (REAL DATA)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WellnessAnalyticsSection extends StatelessWidget {
  final String wellnessUserId;

  const WellnessAnalyticsSection({
    Key? key,
    required this.wellnessUserId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Business Insights',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // ---------------- STATS CARDS ----------------
          Row(
            children: [
              _statCard(
                title: 'Product Interest',
                stream: firestore
                    .collection('product_interests')
                    .where('wellnessId', isEqualTo: wellnessUserId)
                    .snapshots(),
              ),
              const SizedBox(width: 12),
              _statCard(
                title: 'Booking Requests',
                stream: firestore
                    .collection('booking_requests')
                    .where('wellnessId', isEqualTo: wellnessUserId)
                    .snapshots(),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              _statCard(
                title: 'Accepted Bookings',
                stream: firestore
                    .collection('booking_requests')
                    .where('wellnessId', isEqualTo: wellnessUserId)
                    .where('status', isEqualTo: 'accepted')
                    .snapshots(),
              ),
              const SizedBox(width: 12),
              _statCard(
                title: 'Rejected Bookings',
                stream: firestore
                    .collection('booking_requests')
                    .where('wellnessId', isEqualTo: wellnessUserId)
                    .where('status', isEqualTo: 'rejected')
                    .snapshots(),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ---------------- HIGH INTENT USERS ----------------
          const Text(
            'High Intent Users',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          StreamBuilder<QuerySnapshot>(
            stream: firestore
                .collection('booking_requests')
                .where('wellnessId', isEqualTo: wellnessUserId)
                .orderBy('createdAt', descending: true)
                .limit(5)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final docs = snapshot.data?.docs ?? [];

              if (docs.isEmpty) {
                return const Text(
                  'No high intent users yet',
                  style: TextStyle(color: Colors.grey),
                );
              }

              return Column(
                children: docs.map((d) {
                  final data = d.data() as Map<String, dynamic>;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 6,
                        )
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person, size: 32),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data['service'] ?? '',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                              Text(
                                'Status: ${data['status']}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          data['preferredDate'] ?? '',
                          style: const TextStyle(fontSize: 12),
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

  // ---------------- STAT CARD ----------------
  Widget _statCard({
    required String title,
    required Stream<QuerySnapshot> stream,
  }) {
    return Expanded(
      child: StreamBuilder<QuerySnapshot>(
        stream: stream,
        builder: (context, snapshot) {
          final count = snapshot.data?.docs.length ?? 0;

          return Container(
            height: 110,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 13),
                ),
                const Spacer(),
                Text(
                  count.toString(),
                  style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
