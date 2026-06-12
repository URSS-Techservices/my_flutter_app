import 'package:flutter/material.dart';
import 'package:halo/screens/profile/profile_theme.dart';

class ProfilePostTile extends StatelessWidget {
  final String? imageUrl;
  final VoidCallback? onTap;
  final String? heroTag;
  final double borderRadius;
  final bool isVideo;
  final int mediaCount;

  const ProfilePostTile({
    super.key,
    required this.imageUrl,
    this.onTap,
    this.heroTag,
    this.borderRadius = 8,
    this.isVideo = false,
    this.mediaCount = 1,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            color: Colors.grey[200],
          ),
          clipBehavior: Clip.hardEdge,
          child: imageUrl != null && imageUrl!.isNotEmpty
              ? Image.network(
                  imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Center(child: Icon(Icons.image, color: Colors.grey)),
                )
              : const Center(child: Icon(Icons.image, color: Colors.grey)),
        ),
        if (isVideo)
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.play_arrow_rounded,
                  color: Colors.white, size: 16),
            ),
          ),
        if (mediaCount > 1)
          Positioned(
            top: 6,
            left: 6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.collections_rounded,
                  color: Colors.white, size: 14),
            ),
          ),
      ],
    );

    if (heroTag != null) {
      content = Hero(tag: heroTag!, child: content);
    }

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: content);
    }
    return content;
  }
}
