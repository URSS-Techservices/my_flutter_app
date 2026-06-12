import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/screens/profile/profile_theme.dart';

class AspirantBioCard extends StatelessWidget {
  final String bio;
  final bool isOwnProfile;

  const AspirantBioCard({
    super.key,
    required this.bio,
    required this.isOwnProfile,
  });

  @override
  Widget build(BuildContext context) {
    final hasBio = bio.trim().isNotEmpty;
    final displayBio = hasBio
        ? bio.trim()
        : (isOwnProfile
            ? 'Add a short bio — tell people what you love (cricket, dance, yoga, etc.).'
            : '');

    if (displayBio.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: ProfileLayout.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Text(
          displayBio,
          style: GoogleFonts.poppins(
            fontSize: 14,
            height: 1.45,
            color: hasBio
                ? ProfileLayout.textPrimary
                : ProfileLayout.textSecondary,
            fontWeight: hasBio ? FontWeight.w400 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
