import 'package:flutter/material.dart';

class ProfilePostTile extends StatelessWidget {
  final String? imageUrl;
  final VoidCallback? onTap;
  final String? heroTag;
  final double borderRadius;

  const ProfilePostTile({
    super.key,
    required this.imageUrl,
    this.onTap,
    this.heroTag,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
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
