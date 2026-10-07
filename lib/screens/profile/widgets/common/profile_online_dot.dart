import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Presence indicator used next to profile titles (aspirant / guru identity rows).
class ProfileOnlineDot extends StatelessWidget {
  final String profileUserId;

  const ProfileOnlineDot({super.key, required this.profileUserId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(profileUserId)
          .snapshots(),
      builder: (context, snapshot) {
        var isOnline = false;
        if (snapshot.hasData) {
          final data = snapshot.data?.data();
          if (data?['isOnline'] == true) {
            isOnline = true;
          } else if (data?['lastSeen'] != null) {
            final lastSeen = (data?['lastSeen'] as Timestamp?)?.toDate();
            if (lastSeen != null) {
              isOnline = DateTime.now().difference(lastSeen).inMinutes < 2;
            }
          }
        }
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: isOnline ? Colors.green : Colors.grey,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
        );
      },
    );
  }
}
