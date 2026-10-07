import 'package:flutter/material.dart';
import 'package:halo/screens/profile/profile_theme.dart';
import 'package:halo/widgets/follow_button.dart';
import 'package:halo/widgets/halo_buttons.dart';

/// Shared follow / message / book / edit row for all profile types.
class ProfileActionRow extends StatelessWidget {
  final bool isOwnProfile;
  final bool isFollowing;
  final VoidCallback onToggleFollow;
  final VoidCallback onMessage;
  final VoidCallback onEditProfile;
  final VoidCallback? onBook;
  final VoidCallback? onSavedPosts;
  final Color accentColor;

  const ProfileActionRow({
    super.key,
    required this.isOwnProfile,
    required this.isFollowing,
    required this.onToggleFollow,
    required this.onMessage,
    required this.onEditProfile,
    this.onBook,
    this.onSavedPosts,
    this.accentColor = ProfileLayout.lavender,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8),
      child: isOwnProfile ? _ownRow() : _visitorRow(),
    );
  }

  Widget _ownRow() {
    return Row(
      children: [
        Expanded(
          child: HaloOutlinedButton(
            label: 'Edit Profile',
            onPressed: onEditProfile,
            borderColor: accentColor,
          ),
        ),
        if (onSavedPosts != null) ...[
          const SizedBox(width: 10),
          IconButton(
            onPressed: onSavedPosts,
            icon: const Icon(
              Icons.bookmark_outline,
              color: ProfileLayout.deepLavender,
            ),
            tooltip: 'Saved posts',
            style: IconButton.styleFrom(
              backgroundColor: ProfileLayout.chipBg,
            ),
          ),
        ],
      ],
    );
  }

  Widget _visitorRow() {
    return Row(
      children: [
        Expanded(
          child: FollowButton(
            isFollowing: isFollowing,
            isLoading: false,
            onPressed: onToggleFollow,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: HaloOutlinedButton(
            label: 'Message',
            onPressed: onMessage,
            borderColor: Colors.grey.shade300,
            icon: onBook == null ? const Icon(Icons.message_outlined) : null,
          ),
        ),
        if (onBook != null) ...[
          const SizedBox(width: 8),
          Expanded(
            child: HaloFilledButton(
              label: 'Book',
              onPressed: onBook,
            ),
          ),
        ],
      ],
    );
  }
}
