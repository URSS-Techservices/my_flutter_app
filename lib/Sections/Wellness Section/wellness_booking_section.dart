// wellness_booking_section.dart
// Visitor booking + owner inbox (shared with guru flow)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:halo/screens/profile/widgets/common/booking_inbox_section.dart';
import 'package:halo/services/booking_requests_service.dart';

class WellnessBookingSection extends StatefulWidget {
  final String wellnessUserId;
  final bool isOwner;

  const WellnessBookingSection({
    super.key,
    required this.wellnessUserId,
    required this.isOwner,
  });

  @override
  State<WellnessBookingSection> createState() => _WellnessBookingSectionState();
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
                decoration: const InputDecoration(labelText: 'Service name'),
              ),
              TextField(
                controller: dateCtrl,
                decoration: const InputDecoration(labelText: 'Preferred date'),
              ),
              TextField(
                controller: timeCtrl,
                decoration: const InputDecoration(labelText: 'Preferred time'),
              ),
              TextField(
                controller: noteCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Additional note'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final user = _auth.currentUser;
              if (user == null ||
                  serviceCtrl.text.isEmpty ||
                  dateCtrl.text.isEmpty ||
                  timeCtrl.text.isEmpty) {
                return;
              }

              await _firestore.collection('booking_requests').add({
                'wellnessId': widget.wellnessUserId,
                'userId': user.uid,
                'service': serviceCtrl.text.trim(),
                'preferredDate': dateCtrl.text.trim(),
                'preferredTime': timeCtrl.text.trim(),
                'note': noteCtrl.text.trim(),
                'status': BookingRequestsService.statusPending,
                'createdAt': FieldValue.serverTimestamp(),
              });

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Booking request sent')),
                );
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isOwner) {
      return BookingInboxSection(
        providerId: widget.wellnessUserId,
        providerKind: BookingProviderKind.wellness,
        isOwner: true,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Book a Visit',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              ElevatedButton(
                onPressed: _openBookingDialog,
                child: const Text('Book Now'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Request a service or tour — the facility will confirm your time.',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}
