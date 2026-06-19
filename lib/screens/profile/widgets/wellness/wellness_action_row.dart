import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/screens/profile/profile_theme.dart';
import 'package:halo/widgets/follow_button.dart';

class WellnessActionRow extends StatelessWidget {
  final bool isOwnProfile;
  final bool isFollowing;
  final VoidCallback onToggleFollow;
  final VoidCallback onMessage;
  final VoidCallback onBook;
  final VoidCallback onEditProfile;
  final Color lavender;
  final Color deepLavender;

  const WellnessActionRow({
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
    if (isOwnProfile) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: onEditProfile,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              side: BorderSide(color: lavender),
              foregroundColor: ProfileLayout.textPrimary,
            ),
            child: Text(
              'Edit Profile',
              style: GoogleFonts.poppins(
                color: ProfileLayout.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Row(
        children: [
          Expanded(
            child: FollowButton(
              isFollowing: isFollowing,
              isLoading: false,
              onPressed: onToggleFollow,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton(
              onPressed: onMessage,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                side: BorderSide(color: Colors.grey.shade300, width: 1.5),
              ),
              child: Text(
                'Message',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: ProfileLayout.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: onBook,
              style: ElevatedButton.styleFrom(
                backgroundColor: deepLavender,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                elevation: 3,
              ),
              child: Text(
                'Book',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
