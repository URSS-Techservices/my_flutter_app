import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/screens/profile/pages/dynamic_profile_page.dart';
import 'package:halo/screens/profile/profile_theme.dart';

enum FollowListKind { followers, following }

/// Lightweight followers / following list for profile stats taps.
class FollowListPage extends StatelessWidget {
  final String userId;
  final FollowListKind kind;

  const FollowListPage({
    super.key,
    required this.userId,
    required this.kind,
  });

  String get _title =>
      kind == FollowListKind.followers ? 'Followers' : 'Following';

  Stream<QuerySnapshot<Map<String, dynamic>>> _stream() {
    final col = kind == FollowListKind.followers ? 'followers' : 'following';
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection(col)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ProfileLayout.bg,
      appBar: AppBar(
        backgroundColor: ProfileLayout.bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Text(
          _title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _stream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: ProfileLayout.lavender),
            );
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Text(
                kind == FollowListKind.followers
                    ? 'No followers yet'
                    : 'Not following anyone yet',
                style: GoogleFonts.poppins(color: Colors.grey.shade600),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: docs.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: Colors.grey.shade200),
            itemBuilder: (context, i) {
              final doc = docs[i];
              final targetId = kind == FollowListKind.followers
                  ? doc.id
                  : (doc.data()['userId'] ?? doc.id).toString();
              return _FollowRow(userId: targetId);
            },
          );
        },
      ),
    );
  }
}

class _FollowRow extends StatelessWidget {
  final String userId;

  const _FollowRow({required this.userId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, snap) {
        final data = snap.data?.data();
        final name = (data?['full_name'] ??
                data?['name'] ??
                data?['username'] ??
                'User')
            .toString();
        final username = (data?['username'] ?? '').toString();
        final photo = (data?['profilePhoto'] ?? '').toString();

        return ListTile(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DynamicProfilePage(profileUserId: userId),
              ),
            );
          },
          leading: CircleAvatar(
            backgroundColor: ProfileLayout.chipBg,
            backgroundImage:
                photo.isNotEmpty ? NetworkImage(photo) : null,
            child: photo.isEmpty
                ? Icon(Icons.person, color: ProfileLayout.deepLavender)
                : null,
          ),
          title: Text(
            name,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          subtitle: username.isNotEmpty
              ? Text('@$username', style: GoogleFonts.poppins(fontSize: 12))
              : null,
        );
      },
    );
  }
}
