import 'package:flutter/material.dart';
import 'package:halo/screens/profile/profile_theme.dart';

/// Circular avatar with white ring + shadow, wrapped in [Hero].
/// Optional [extraStackChildren] render above the circle (e.g. wellness online badge).
class ProfileAvatarHeroShell extends StatelessWidget {
  final ImageProvider avatar;
  final String heroTag;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final List<Widget> extraStackChildren;

  const ProfileAvatarHeroShell({
    super.key,
    required this.avatar,
    required this.heroTag,
    required this.onTap,
    required this.onLongPress,
    this.extraStackChildren = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: heroTag,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: ProfileLayout.avatarSize + 6,
              height: ProfileLayout.avatarSize + 6,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: ProfileLayout.avatarSize / 2,
                backgroundImage: avatar,
              ),
            ),
            ...extraStackChildren,
          ],
        ),
      ),
    );
  }
}
