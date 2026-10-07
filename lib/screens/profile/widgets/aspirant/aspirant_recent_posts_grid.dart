import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/screens/profile/core/profile_posts_queries.dart';
import 'package:halo/screens/profile/widgets/common/profile_post_tile.dart';

class AspirantRecentPostsGrid extends StatelessWidget {
  final bool isPrivate;
  final bool isFollowing;
  final bool isOwnProfile;
  final String profileUserId;
  final Color accentColor;
  final String? Function(Map<String, dynamic> data) imageResolver;
  final void Function(String postId) onTapPost;
  final VoidCallback onTapViewAll;

  const AspirantRecentPostsGrid({
    super.key,
    required this.isPrivate,
    required this.isFollowing,
    required this.isOwnProfile,
    required this.profileUserId,
    required this.accentColor,
    required this.imageResolver,
    required this.onTapPost,
    required this.onTapViewAll,
  });

  @override
  Widget build(BuildContext context) {
    if (isPrivate && !isFollowing && !isOwnProfile) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16),
        child: Text(
          'This account is private.\nFollow to see their posts.',
          style: GoogleFonts.poppins(),
        ),
      );
    }

    final postsQuery = FirebaseFirestore.instance
        .collection('posts')
        .where('userId', isEqualTo: profileUserId)
        .limit(30);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Posts',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: postsQuery.snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return SizedBox(
                  height: 120,
                  child: Center(
                    child: CircularProgressIndicator(color: accentColor),
                  ),
                );
              }
              final allDocs = snap.data?.docs ?? [];
              final sortedDocs =
                  List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
                allDocs,
              )..sort(ProfilePostsQueries.comparePostDocumentsByTimeDesc);
              final docs = sortedDocs.take(12).toList();
              if (docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text('No posts yet', style: GoogleFonts.poppins()),
                );
              }
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemBuilder: (context, idx) {
                  final doc = docs[idx];
                  final imageUrl = imageResolver(doc.data());
                  return ProfilePostTile(
                    imageUrl: imageUrl,
                    heroTag: 'post-${doc.id}',
                    onTap: () => onTapPost(doc.id),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onTapViewAll,
              child: const Text('View All Posts →'),
            ),
          ),
        ],
      ),
    );
  }
}
