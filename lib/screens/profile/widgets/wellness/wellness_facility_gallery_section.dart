import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/screens/profile/profile_theme.dart';

class WellnessFacilityGallerySection extends StatelessWidget {
  final List<Map<String, dynamic>> images;
  final bool isOwnProfile;
  final VoidCallback? onAdd;
  final VoidCallback? onViewAll;

  const WellnessFacilityGallerySection({
    super.key,
    required this.images,
    required this.isOwnProfile,
    this.onAdd,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    if (!isOwnProfile && images.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: ProfileLayout.lavender.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.photo_library, color: ProfileLayout.lavender, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Facility Gallery',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              if (isOwnProfile && onAdd != null)
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: ProfileLayout.lavender),
                  onPressed: onAdd,
                )
              else if (images.isNotEmpty && onViewAll != null)
                TextButton(onPressed: onViewAll, child: const Text('View All')),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (images.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('No gallery photos yet', style: GoogleFonts.poppins(color: Colors.grey)),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: images.length > 6 ? 6 : images.length,
              itemBuilder: (context, index) {
                final url = (images[index]['imageUrl'] ?? images[index]['url'] ?? '').toString();
                return ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (url.isNotEmpty)
                        CachedNetworkImage(imageUrl: url, fit: BoxFit.cover)
                      else
                        ColoredBox(
                          color: Colors.grey.shade300,
                          child: Icon(Icons.image, color: Colors.grey.shade600),
                        ),
                      if (index == 5 && images.length > 6)
                        Container(
                          color: Colors.black.withValues(alpha: 0.5),
                          alignment: Alignment.center,
                          child: Text(
                            '+${images.length - 6}',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
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
    );
  }
}
