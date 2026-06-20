import 'package:flutter/material.dart';
import 'package:halo/screens/profile/profile_theme.dart';
import 'package:halo/widgets/follow_button.dart';

class GuruActionRow extends StatelessWidget {
  final bool isOwnProfile;
  final bool isFollowing;
  final VoidCallback onToggleFollow;
  final VoidCallback onMessage;
  final VoidCallback onBook;
  final VoidCallback onEditProfile;
  final Color lavender;
  final Color deepLavender;

  const GuruActionRow({
    super.key,
    required this.isOwnProfile,
    required this.isFollowing,
    required this.onToggleFollow,
    required this.onMessage,
    required this.onBook,
    required this.onEditProfile,
    required this.lavender,
    required this.deepLavender,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8),
      child: isOwnProfile
          ? SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onEditProfile,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  side: BorderSide(color: deepLavender),
                  foregroundColor: ProfileLayout.textPrimary,
                ),
                child: const Text(
                  'Edit Profile',
                  style: TextStyle(
                    color: ProfileLayout.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          : Row(
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
                  child: OutlinedButton(
                    onPressed: onMessage,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      'Message',
                      style: TextStyle(color: ProfileLayout.textPrimary),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onBook,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: deepLavender,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 2,
                    ),
                    child: const Text(
                      'Book',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
