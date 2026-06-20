import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/screens/profile/profile_theme.dart';
import 'package:halo/screens/profile/widgets/common/profile_post_image_url.dart';

/// Instagram-style pinned post/reel highlights under the profile bio.
class ProfileHighlightsRow extends StatelessWidget {
  final List<Map<String, dynamic>> posts;
  final void Function(String postId) onTapPost;
  final Color accentColor;

  const ProfileHighlightsRow({
    super.key,
    required this.posts,
    required this.onTapPost,
    this.accentColor = ProfileLayout.deepLavender,
  });

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) return const SizedBox.shrink();

    final highlights = posts.take(3).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Highlights',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: ProfileLayout.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: highlights.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final post = highlights[index];
                final postId = (post['id'] ?? '').toString();
                final imageUrl = profilePostImageUrlFromMap(post) ?? '';
                final isVideo = post['isVideo'] == true ||
                    (post['type'] ?? '').toString() == 'video';
                final music = post['music'];
                final hasMusic = music is Map && (music['title'] ?? '').toString().isNotEmpty;

                return GestureDetector(
                  onTap: postId.isEmpty ? null : () => onTapPost(postId),
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: accentColor, width: 2),
                        ),
                        child: ClipOval(
                          child: imageUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => _fallback(isVideo),
                                )
                              : _fallback(isVideo),
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 72,
                        child: Text(
                          hasMusic
                              ? (music['title'] ?? 'Reel').toString()
                              : (isVideo ? 'Reel' : 'Photo'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: ProfileLayout.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallback(bool isVideo) {
    return ColoredBox(
      color: ProfileLayout.chipBg,
      child: Icon(
        isVideo ? Icons.play_circle_outline : Icons.image_outlined,
        color: accentColor,
      ),
    );
  }
}
