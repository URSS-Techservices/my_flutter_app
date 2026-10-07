import 'package:flutter/material.dart';

/// Cover image area with Hero + gradient overlay (profile headers).
/// Callbacks remain on the outer [GestureDetector] — preserves tap/long-press behavior.
class ProfileCoverHero extends StatelessWidget {
  final ImageProvider cover;
  final String heroTag;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const ProfileCoverHero({
    super.key,
    required this.cover,
    required this.heroTag,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Hero(
            tag: heroTag,
            child: Container(
              decoration: BoxDecoration(
                image: DecorationImage(image: cover, fit: BoxFit.cover),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.black.withOpacity(0.25), Colors.transparent],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
