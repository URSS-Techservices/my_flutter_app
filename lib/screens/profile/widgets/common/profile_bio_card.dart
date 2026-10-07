import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/screens/profile/profile_theme.dart';

/// Shared bio card for aspirant, guru, and wellness profiles.
class ProfileBioCard extends StatelessWidget {
  final String bio;
  final bool isOwnProfile;
  final String emptyHint;
  final VoidCallback? onEdit;
  final int? maxLines;

  const ProfileBioCard({
    super.key,
    required this.bio,
    required this.isOwnProfile,
    required this.emptyHint,
    this.onEdit,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    final hasBio = bio.trim().isNotEmpty;
    final displayBio = hasBio ? bio.trim() : (isOwnProfile ? emptyHint : '');

    if (displayBio.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                displayBio,
                maxLines: maxLines,
                overflow: maxLines == null ? null : TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  height: 1.45,
                  color: hasBio ? Colors.black87 : ProfileLayout.deepLavender,
                  fontWeight: hasBio ? FontWeight.w400 : FontWeight.w500,
                ),
              ),
            ),
            if (isOwnProfile && onEdit != null)
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: onEdit,
                color: ProfileLayout.deepLavender,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
      ),
    );
  }
}
