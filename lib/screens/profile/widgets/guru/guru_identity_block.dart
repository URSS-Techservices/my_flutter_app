import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/screens/profile/profile_theme.dart';
import 'package:halo/screens/profile/widgets/common/profile_identity_layout.dart';
import 'package:halo/screens/profile/widgets/common/profile_online_dot.dart';

class GuruIdentityBlock extends StatelessWidget {
  final Widget avatar;
  final String profileUserId;
  final String fullName;
  final String username;
  final String primaryCategory;
  final String city;
  final int? experienceYears;
  final List<String> languages;
  final String trainingStyle;
  final double rating;
  final int reviewCount;

  const GuruIdentityBlock({
    super.key,
    required this.avatar,
    required this.profileUserId,
    required this.fullName,
    required this.username,
    required this.primaryCategory,
    required this.city,
    required this.experienceYears,
    required this.languages,
    required this.trainingStyle,
    required this.rating,
    required this.reviewCount,
  });

  @override
  Widget build(BuildContext context) {
    final title = fullName.isNotEmpty
        ? fullName
        : (username.isNotEmpty ? '@$username' : 'Guru');

    return ProfileIdentityLayout(
      avatar: avatar,
      details: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: ProfileLayout.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              ProfileOnlineDot(profileUserId: profileUserId),
            ],
          ),
          const SizedBox(height: 4),
          if (username.isNotEmpty)
            Text(
              '@$username',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: ProfileLayout.textSecondary,
              ),
            ),
          const SizedBox(height: 6),
          if (primaryCategory.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: ProfileLayout.chipBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: ProfileLayout.deepLavender.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                primaryCategory,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: ProfileLayout.deepLavender,
                ),
              ),
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (city.isNotEmpty) ...[
                Icon(Icons.location_on_outlined,
                    size: 14, color: ProfileLayout.textMuted),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    city,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: ProfileLayout.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              if (experienceYears != null) ...[
                const SizedBox(width: 12),
                Icon(Icons.school_outlined,
                    size: 14, color: ProfileLayout.textMuted),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    '$experienceYears+ yrs exp',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: ProfileLayout.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          if (languages.isNotEmpty)
            Text(
              'Languages: ${languages.join(', ')}',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: ProfileLayout.textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          if (trainingStyle.isNotEmpty)
            Text(
              'Training style: $trainingStyle',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: ProfileLayout.textSecondary,
              ),
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (rating > 0 || reviewCount > 0) ...[
                Icon(Icons.star_rounded, color: Colors.amber.shade700, size: 18),
                const SizedBox(width: 4),
                Text(
                  rating.toStringAsFixed(1),
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: ProfileLayout.textPrimary,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '($reviewCount reviews)',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: ProfileLayout.textSecondary,
                  ),
                ),
              ] else
                Text(
                  'No ratings yet',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: ProfileLayout.textMuted,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
