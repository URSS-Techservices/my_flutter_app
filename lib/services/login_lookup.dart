import 'package:cloud_firestore/cloud_firestore.dart';

/// Resolves a login ID (email, username, or phone) to the account email.
///
/// Tries [username_lower] (case-insensitive), legacy [username], [phone], and
/// legacy [mobile] so web and mobile behave the same.
Future<String?> resolveLoginEmail(String input) async {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;
  if (trimmed.contains('@')) return trimmed;

  final firestore = FirebaseFirestore.instance;
  final lower = trimmed.toLowerCase();

  QuerySnapshot<Map<String, dynamic>> snap = await firestore
      .collection('users')
      .where('username_lower', isEqualTo: lower)
      .limit(1)
      .get();

  if (snap.docs.isEmpty) {
    snap = await firestore
        .collection('users')
        .where('username', isEqualTo: trimmed)
        .limit(1)
        .get();
  }

  if (snap.docs.isEmpty) {
    snap = await firestore
        .collection('users')
        .where('phone', isEqualTo: trimmed)
        .limit(1)
        .get();
  }

  if (snap.docs.isEmpty) {
    snap = await firestore
        .collection('users')
        .where('mobile', isEqualTo: trimmed)
        .limit(1)
        .get();
  }

  if (snap.docs.isEmpty) return null;

  final email = snap.docs.first.data()['email'] as String?;
  if (email == null || email.trim().isEmpty) return null;
  return email.trim();
}
