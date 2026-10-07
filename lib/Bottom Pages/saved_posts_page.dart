import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/Profile Pages/aspirant_profile_page.dart' as aspirant_profile;
import 'package:halo/services/save_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

const Color _kPrimary = Color(0xFF5B3FA3);
const Color _kBackground = Color(0xFFF4F1FB);

/// Resolves post thumbnail URL from post data.
String? _postImageUrl(Map<String, dynamic> data) {
  final imageUrl = data['imageUrl']?.toString();
  if (imageUrl != null && imageUrl.isNotEmpty) return imageUrl;
  final images = data['images'];
  if (images is List && images.isNotEmpty) return images.first?.toString();
  final media = data['media'];
  if (media is List && media.isNotEmpty) {
    final first = media.first;
    if (first is Map && first['url'] != null) return first['url']?.toString();
  }
  return null;
}

class SavedPostsPage extends StatelessWidget {
  const SavedPostsPage({Key? key}) : super(key: key);

  static const int _whereInLimit = 30;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    if (uid.isEmpty) {
      return Scaffold(
        backgroundColor: _kBackground,
        appBar: AppBar(
          title: const Text('Saved'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
        ),
        body: Center(
          child: Text(
            'Sign in to see your saved posts',
            style: GoogleFonts.poppins(color: Colors.grey.shade700),
          ),
        ),
      );
    }

    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

    return Scaffold(
      backgroundColor: _kBackground,
      appBar: AppBar(
        title: Text(
          'Saved',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: userRef.snapshots(),
        builder: (context, userSnap) {
          if (!userSnap.hasData) {
            return const Center(child: CircularProgressIndicator(color: _kPrimary));
          }
          final savedPosts =
              userSnap.data!.data()?['savedPosts'] as Map<String, dynamic>?;
          final postIds = (savedPosts?.keys.toList() ?? [])
              .map((e) => e.toString())
              .where((s) => s.isNotEmpty)
              .toList();

          if (postIds.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bookmark_border, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No saved posts',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Save posts from your feed to find them here.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          return FutureBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
            future: _fetchPostsByIds(postIds),
            builder: (context, postsSnap) {
              if (postsSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: _kPrimary));
              }
              final docs = postsSnap.data ?? [];
              final order = {for (var i = 0; i < postIds.length; i++) postIds[i]: i};
              docs.sort((a, b) => (order[a.id] ?? 0).compareTo(order[b.id] ?? 0));

              return GridView.builder(
                padding: const EdgeInsets.all(4),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                  childAspectRatio: 1,
                ),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data();
                  final imageUrl = _postImageUrl(data);
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              aspirant_profile.PostDetailsPage(postId: doc.id),
                        ),
                      );
                    },
                    child: Container(
                      color: Colors.grey.shade300,
                      child: imageUrl != null && imageUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                              errorWidget: (_, __, ___) =>
                                  const Icon(Icons.image_not_supported, color: Colors.grey),
                            )
                          : const Icon(Icons.image, color: Colors.grey),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  /// Fetches posts by IDs in batches of [_whereInLimit] (Firestore limit).
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _fetchPostsByIds(
    List<String> postIds,
  ) async {
    if (postIds.isEmpty) return [];
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> result = [];
    for (var i = 0; i < postIds.length; i += _whereInLimit) {
      final batch = postIds.skip(i).take(_whereInLimit).toList();
      final snap = await FirebaseFirestore.instance
          .collection('posts')
          .where(FieldPath.documentId, whereIn: batch)
          .get();
      result.addAll(snap.docs.cast<QueryDocumentSnapshot<Map<String, dynamic>>>());
    }
    return result;
  }
}
