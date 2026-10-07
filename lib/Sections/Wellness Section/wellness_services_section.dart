// wellness_services_section.dart
// SERVICES + AVAILABILITY + INTEREST TRACKING

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:halo/core/halo_toast.dart';
class WellnessServicesSection extends StatefulWidget {
  final String wellnessUserId;
  final bool isOwner;

  const WellnessServicesSection({
    Key? key,
    required this.wellnessUserId,
    required this.isOwner,
  }) : super(key: key);

  @override
  State<WellnessServicesSection> createState() =>
      _WellnessServicesSectionState();
}

class _WellnessServicesSectionState extends State<WellnessServicesSection> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _addServiceDialog() async {
    final titleCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final durationCtrl = TextEditingController();
    String availability = 'Available';

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Service'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: titleCtrl,
                decoration:
                const InputDecoration(labelText: 'Service title'),
              ),
              TextField(
                controller: priceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Price'),
              ),
              TextField(
                controller: durationCtrl,
                decoration:
                const InputDecoration(labelText: 'Duration (eg 60 min)'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: availability,
                items: const [
                  DropdownMenuItem(
                      value: 'Available', child: Text('Available')),
                  DropdownMenuItem(
                      value: 'Limited', child: Text('Limited')),
                  DropdownMenuItem(
                      value: 'Full', child: Text('Full')),
                ],
                onChanged: (v) => availability = v!,
                decoration:
                const InputDecoration(labelText: 'Availability'),
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
              if (titleCtrl.text.isEmpty) return;

              await _firestore
                  .collection('users')
                  .doc(widget.wellnessUserId)
                  .collection('services')
                  .add({
                'title': titleCtrl.text.trim(),
                'price': priceCtrl.text.trim(),
                'duration': durationCtrl.text.trim(),
                'availability': availability,
                'createdAt': FieldValue.serverTimestamp(),
              });

              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _registerInterest(String serviceId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('service_interests').add({
      'wellnessId': widget.wellnessUserId,
      'serviceId': serviceId,
      'userId': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Color _availabilityColor(String v) {
    switch (v) {
      case 'Available':
        return Colors.green;
      case 'Limited':
        return Colors.orange;
      case 'Full':
        return Colors.red;
      default:
        return Colors.grey;
    }
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
                'Services',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              if (widget.isOwner)
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _addServiceDialog,
                ),
            ],
          ),

          // ---------- SERVICES LIST ----------
          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('users')
                .doc(widget.wellnessUserId)
                .collection('services')
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
                        ? 'Add your first service'
                        : 'No services available',
                    style: const TextStyle(color: Colors.grey),
                  ),
                );
              }

              return Column(
                children: docs.map((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final availability = data['availability'] ?? 'Available';

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
                          data['title'] ?? '',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${data['duration']} • ₹${data['price']}',
                          style:
                          const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                          children: [
                            Chip(
                              label: Text(availability),
                              backgroundColor:
                              _availabilityColor(availability)
                                  .withOpacity(0.15),
                            ),
                            ElevatedButton(
                              onPressed: availability == 'Full'
                                  ? null
                                  : () {
                                _registerInterest(d.id);
                                HaloToast.show('Interest registered');
                              },
                              child: const Text('Interested'),
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
