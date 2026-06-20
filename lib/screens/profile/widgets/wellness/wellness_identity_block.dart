import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/screens/profile/profile_theme.dart';
import 'package:halo/screens/profile/widgets/common/profile_identity_layout.dart';

class WellnessIdentityBlock extends StatelessWidget {
  final Widget avatar;
  final String businessName;
  final String username;
  final String category;
  final String location;
  final double rating;
  final int reviewCount;
  final bool isOwnProfile;
  final VoidCallback onEditCategory;

  const WellnessIdentityBlock({
    super.key,
    required this.avatar,
    required this.businessName,
    required this.username,
    required this.category,
    required this.location,
    this.rating = 0,
    this.reviewCount = 0,
    required this.isOwnProfile,
    required this.onEditCategory,
  });

  @override
  Widget build(BuildContext context) {
    return ProfileIdentityLayout(
      avatar: avatar,
      details: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            businessName.isNotEmpty ? businessName : 'Business Name',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: ProfileLayout.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          if (username.isNotEmpty)
            Text(
              '@$username',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: ProfileLayout.textSecondary,
                fontWeight: FontWeight.w400,
              ),
            ),
          const SizedBox(height: 6),
          if (rating > 0)
            Row(
              children: [
                Icon(Icons.star_rounded, size: 16, color: Colors.amber[700]),
                const SizedBox(width: 4),
                Text(
                  rating.toStringAsFixed(1),
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ProfileLayout.textPrimary,
                  ),
                ),
                if (reviewCount > 0) ...[
                  const SizedBox(width: 4),
                  Text(
                    '($reviewCount reviews)',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: ProfileLayout.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          if (rating > 0) const SizedBox(height: 6),
          _CategoryChip(
            category: category,
            isOwnProfile: isOwnProfile,
            onEditCategory: onEditCategory,
          ),
          const SizedBox(height: 6),
          if (location.isNotEmpty)
            Row(
              children: [
                Icon(Icons.location_on_outlined,
                    size: 14, color: ProfileLayout.textMuted),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    location,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: ProfileLayout.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String category;
  final bool isOwnProfile;
  final VoidCallback onEditCategory;
  const _CategoryChip({
    required this.category,
    required this.isOwnProfile,
    required this.onEditCategory,
  });

  @override
  Widget build(BuildContext context) {
    if (category.isNotEmpty) {
      return GestureDetector(
        onTap: isOwnProfile ? onEditCategory : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: ProfileLayout.chipBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: ProfileLayout.deepLavender.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  category,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: ProfileLayout.deepLavender,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isOwnProfile) ...[
                const SizedBox(width: 4),
                Icon(Icons.edit, size: 12, color: ProfileLayout.lavender),
              ],
            ],
          ),
        ),
      );
    }
    if (!isOwnProfile) return const SizedBox.shrink();
    return GestureDetector(
      onTap: onEditCategory,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: ProfileLayout.chipBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: ProfileLayout.deepLavender.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Add Category',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: ProfileLayout.deepLavender,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.add, size: 12, color: ProfileLayout.lavender),
          ],
        ),
      ),
    );
  }
}
