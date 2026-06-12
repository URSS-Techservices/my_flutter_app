import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/screens/profile/core/profile_posts_queries.dart';
import 'package:halo/screens/profile/profile_theme.dart';
import 'package:halo/screens/profile/widgets/common/profile_post_tile.dart';

enum AspirantPostsFilter { all, photos, reels }

/// Full Instagram-style posts grid for aspirant profile Posts tab.
class AspirantPostsTab extends StatefulWidget {
  final String profileUserId;
  final bool isPrivate;
  final bool isFollowing;
  final bool isOwnProfile;
  final void Function(String postId) onTapPost;
  final String? Function(Map<String, dynamic> data) imageResolver;

  const AspirantPostsTab({
    super.key,
    required this.profileUserId,
    required this.isPrivate,
    required this.isFollowing,
    required this.isOwnProfile,
    required this.onTapPost,
    required this.imageResolver,
  });

  @override
  State<AspirantPostsTab> createState() => _AspirantPostsTabState();
}

class _AspirantPostsTabState extends State<AspirantPostsTab> {
  AspirantPostsFilter _filter = AspirantPostsFilter.all;

  bool _matchesFilter(Map<String, dynamic> data) {
    final isVideo = data['isVideo'] == true ||
        (data['type'] ?? '').toString() == 'video' ||
        ((data['videoUrl'] ?? '').toString().isNotEmpty);
    switch (_filter) {
      case AspirantPostsFilter.all:
        return true;
      case AspirantPostsFilter.photos:
        return !isVideo;
      case AspirantPostsFilter.reels:
        return isVideo;
    }
  }

  int _mediaCount(Map<String, dynamic> data) {
    final media = data['media'];
    if (media is List && media.isNotEmpty) return media.length;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isPrivate && !widget.isFollowing && !widget.isOwnProfile) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'This account is private.\nFollow to see their posts.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: Colors.grey.shade600),
          ),
        ),
      );
    }

    final query = FirebaseFirestore.instance
        .collection('posts')
        .where('userId', isEqualTo: widget.profileUserId);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              _FilterChip(
                label: 'All',
                selected: _filter == AspirantPostsFilter.all,
                onTap: () =>
                    setState(() => _filter = AspirantPostsFilter.all),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Photos',
                selected: _filter == AspirantPostsFilter.photos,
                onTap: () =>
                    setState(() => _filter = AspirantPostsFilter.photos),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Reels',
                selected: _filter == AspirantPostsFilter.reels,
                onTap: () =>
                    setState(() => _filter = AspirantPostsFilter.reels),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: query.snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: ProfileLayout.lavender,
                  ),
                );
              }
              final allDocs = snap.data?.docs ?? [];
              final sorted =
                  List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
                allDocs,
              )..sort(ProfilePostsQueries.comparePostDocumentsByTimeDesc);
              final docs = sorted
                  .where((d) => _matchesFilter(d.data()))
                  .toList();

              if (docs.isEmpty) {
                return Center(
                  child: Text(
                    'No posts yet',
                    style: GoogleFonts.poppins(color: Colors.grey.shade600),
                  ),
                );
              }

              return GridView.builder(
                padding: const EdgeInsets.all(2),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 2,
                  mainAxisSpacing: 2,
                ),
                itemCount: docs.length,
                itemBuilder: (context, idx) {
                  final doc = docs[idx];
                  final data = doc.data();
                  final isVideo = data['isVideo'] == true ||
                      (data['videoUrl'] ?? '').toString().isNotEmpty;
                  return ProfilePostTile(
                    imageUrl: widget.imageResolver(data),
                    heroTag: 'post-${doc.id}',
                    isVideo: isVideo,
                    mediaCount: _mediaCount(data),
                    onTap: () => widget.onTapPost(doc.id),
                    borderRadius: 0,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? ProfileLayout.deepLavender : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? ProfileLayout.deepLavender
                  : Colors.grey.shade300,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : ProfileLayout.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
