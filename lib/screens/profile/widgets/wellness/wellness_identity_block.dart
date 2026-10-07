import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/screens/profile/widgets/common/profile_identity_layout.dart';

class WellnessIdentityBlock extends StatelessWidget {
  final Widget avatar;
  final String businessName;
  final String username;
  final String category;
  final String location;
  final bool isOwnProfile;
  final VoidCallback onEditCategory;

  const WellnessIdentityBlock({
    super.key,
    required this.avatar,
    required this.businessName,
    required this.username,
    required this.category,
    required this.location,
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
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            username.isNotEmpty ? '@$username' : '',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: const Color(0xFF8E8E8E),
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 6),
          _CategoryChip(
            category: category,
            isOwnProfile: isOwnProfile,
            onEditCategory: onEditCategory,
          ),
          const SizedBox(height: 6),
          if (location.isNotEmpty)
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF8E8E8E)),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    location,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: const Color(0xFF8E8E8E),
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
    const lavender = Color(0xFFA58CE3);
    const deepLavender = Color(0xFF5B3FA3);
    if (category.isNotEmpty) {
      return GestureDetector(
        onTap: isOwnProfile ? onEditCategory : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: lavender.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: lavender.withOpacity(0.3), width: 1),
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
                    color: deepLavender,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isOwnProfile) ...[
                const SizedBox(width: 4),
                const Icon(Icons.edit, size: 12, color: lavender),
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
          color: lavender.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: lavender.withOpacity(0.3), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Add Category',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: deepLavender,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.add, size: 12, color: lavender),
          ],
        ),
      ),
    );
  }
}
