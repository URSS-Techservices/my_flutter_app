import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GuruRecentPostsSection extends StatelessWidget {
  final String profileUserId;
  final bool isOwnProfile;
  final Color accentColor;
  final VoidCallback onCreatePost;
  final String? profilePhotoUrl;
  final String username;
  final String city;
  final String Function(dynamic timestamp) formatPostTime;
  final String? Function(Map<String, dynamic>) imageResolver;

  const GuruRecentPostsSection({
    super.key,
    required this.profileUserId,
    required this.isOwnProfile,
    required this.accentColor,
    required this.onCreatePost,
    required this.profilePhotoUrl,
    required this.username,
    required this.city,
    required this.formatPostTime,
    required this.imageResolver,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Posts',
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              if (isOwnProfile)
                IconButton(
                  icon: const Icon(Icons.add_box_outlined, size: 20),
                  onPressed: onCreatePost,
                  color: accentColor,
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('posts')
              .where('userId', isEqualTo: profileUserId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 20),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final allDocs = snapshot.data?.docs ?? [];
            final sortedDocs = List.from(allDocs)
              ..sort((a, b) {
                final aTimestamp = a.data()['timestamp'] ?? a.data()['createdAt'];
                final bTimestamp = b.data()['timestamp'] ?? b.data()['createdAt'];
                if (aTimestamp is Timestamp && bTimestamp is Timestamp) {
                  return bTimestamp.compareTo(aTimestamp);
                }
                return 0;
              });
            final docs = sortedDocs.take(6).toList();
            if (docs.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: isOwnProfile
                    ? TextButton.icon(
                        onPressed: onCreatePost,
                        icon: const Icon(Icons.add_circle_outline, size: 18),
                        label: const Text('Create your first post'),
                        style: TextButton.styleFrom(foregroundColor: accentColor),
                      )
                    : Text('No posts yet', style: GoogleFonts.poppins(fontSize: 14, color: Colors.black54)),
              );
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final d = docs[i].data();
                  final imageUrl = imageResolver(d);
                  final ts = d['timestamp'] ?? d['createdAt'];
                  return Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.grey[200],
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: imageUrl != null && imageUrl.isNotEmpty
                            ? Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.image, color: Colors.grey)),
                              )
                            : const Center(child: Icon(Icons.image, color: Colors.grey)),
                      ),
                      Positioned(
                        left: 4,
                        right: 4,
                        bottom: 4,
                        child: Text(
                          formatPostTime(ts),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}
