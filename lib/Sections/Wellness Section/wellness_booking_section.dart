// wellness_booking_section.dart
// FULL BOOKING REQUEST SYSTEM (VISITOR + OWNER)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:halo/core/halo_toast.dart';
class WellnessBookingSection extends StatefulWidget {
  final String wellnessUserId;
  final bool isOwner;

  const WellnessBookingSection({
    Key? key,
    required this.wellnessUserId,
    required this.isOwner,
  }) : super(key: key);

  @override
  State<WellnessBookingSection> createState() =>
      _WellnessBookingSectionState();
}

class _WellnessBookingSectionState extends State<WellnessBookingSection> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _openBookingDialog() async {
    final serviceCtrl = TextEditingController();
    final dateCtrl = TextEditingController();
    final timeCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Book a Service'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: serviceCtrl,
                decoration:
                const InputDecoration(labelText: 'Service name'),
              ),
              TextField(
                controller: dateCtrl,
                decoration:
                const InputDecoration(labelText: 'Preferred date'),
              ),
              TextField(
                controller: timeCtrl,
                decoration:
                const InputDecoration(labelText: 'Preferred time'),
              ),
              TextField(
                controller: noteCtrl,
                maxLines: 3,
                decoration:
                const InputDecoration(labelText: 'Additional note'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final user = _auth.currentUser;
              if (user == null ||
                  serviceCtrl.text.isEmpty ||
                  dateCtrl.text.isEmpty ||
                  timeCtrl.text.isEmpty) return;

              await _firestore.collection('booking_requests').add({
                'wellnessId': widget.wellnessUserId,
                'userId': user.uid,
                'service': serviceCtrl.text.trim(),
                'preferredDate': dateCtrl.text.trim(),
                'preferredTime': timeCtrl.text.trim(),
                'note': noteCtrl.text.trim(),
                'status': 'pending',
                'createdAt': FieldValue.serverTimestamp(),
              });

              Navigator.pop(context);

              HaloToast.show('Booking request sent');
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateStatus(String id, String status) async {
    await _firestore
        .collection('booking_requests')
        .doc(id)
        .update({'status': status});
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---------- HEADER ----------
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Bookings',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              if (!widget.isOwner)
                ElevatedButton(
                  onPressed: _openBookingDialog,
                  child: const Text('Book Now'),
                ),
            ],
          ),

          const SizedBox(height: 10),

          // ---------- BOOKINGS LIST ----------
          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('booking_requests')
                .where('wellnessId',
                isEqualTo: widget.wellnessUserId)
                .orderBy('createdAt', descending: true)
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
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    widget.isOwner
                        ? 'No booking requests yet'
                        : 'No bookings yet',
                    style: const TextStyle(color: Colors.grey),
                  ),
                );
              }

              return Column(
                children: docs.map((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final status = data['status'];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['service'] ?? '',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${data['preferredDate']} • ${data['preferredTime']}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        if (data['note'] != null &&
                            data['note'].toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              data['note'],
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                          children: [
                            Chip(
                              label: Text(status.toString().toUpperCase()),
                              backgroundColor: status == 'accepted'
                                  ? Colors.green[100]
                                  : status == 'rejected'
                                  ? Colors.red[100]
                                  : Colors.orange[100],
                            ),
                            if (widget.isOwner && status == 'pending')
                              Row(
                                children: [
                                  TextButton(
                                    onPressed: () =>
                                        _updateStatus(d.id, 'rejected'),
                                    child: const Text('Reject'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () =>
                                        _updateStatus(d.id, 'accepted'),
                                    child: const Text('Accept'),
                                  ),
                                ],
                              ),
                          ],
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
