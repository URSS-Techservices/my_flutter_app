import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WellnessRecentPostsSection extends StatelessWidget {
  final List<Map<String, dynamic>> recentPosts;
  final VoidCallback onViewAll;
  final Color mutedTextColor;
  final Color accentColor;

  const WellnessRecentPostsSection({
    super.key,
    required this.recentPosts,
    required this.onViewAll,
    required this.mutedTextColor,
    required this.accentColor,
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
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                  letterSpacing: -0.5,
                ),
              ),
              TextButton(
                onPressed: onViewAll,
                child: Text(
                  'View All Posts →',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: accentColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (recentPosts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Text(
              'No posts yet',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: mutedTextColor,
                fontWeight: FontWeight.w400,
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: recentPosts.length > 9 ? 9 : recentPosts.length,
              itemBuilder: (context, index) {
                final post = recentPosts[index];
                final imageUrl = (post['imageUrl'] ?? '').toString();
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: imageUrl.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.image, color: Colors.grey),
                            ),
                          ),
                        )
                      : const Center(child: Icon(Icons.image, color: Colors.grey)),
                );
              },
            ),
          ),
      ],
    );
  }
}
