import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/screens/profile/profile_theme.dart';
import 'package:halo/screens/profile/widgets/common/profile_identity_layout.dart';
import 'package:halo/screens/profile/widgets/common/profile_online_dot.dart';

class AspirantIdentityBlock extends StatelessWidget {
  final Widget avatar;
  final String profileUserId;
  final String fullName;
  final String username;
  final List<String> interests;
  final String fitnessTag;
  final String city;
  final int? age;
  final String? primaryCategory;
  final String? fitnessLevel;
  final List<String> healthNotes;
  final bool showHealthNotes;
  final ValueChanged<String>? onInterestTap;

  const AspirantIdentityBlock({
    super.key,
    required this.avatar,
    required this.profileUserId,
    required this.fullName,
    required this.username,
    required this.interests,
    required this.fitnessTag,
    required this.city,
    required this.age,
    this.primaryCategory,
    this.fitnessLevel,
    this.healthNotes = const [],
    this.showHealthNotes = false,
    this.onInterestTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = fullName.isNotEmpty
        ? fullName
        : username.isNotEmpty
            ? '@$username'
            : 'No name';

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
          if (primaryCategory != null && primaryCategory!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: ProfileLayout.chipBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: ProfileLayout.deepLavender.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  primaryCategory!,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: ProfileLayout.deepLavender,
                  ),
                ),
              ),
            ),
          if (fitnessLevel != null && fitnessLevel!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: ProfileLayout.cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  fitnessLevel!,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: ProfileLayout.textSecondary,
                  ),
                ),
              ),
            ),
          if (interests.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ...interests.take(5).map((interest) {
                  return ActionChip(
                    label: Text(
                      interest,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: ProfileLayout.textPrimary,
                      ),
                    ),
                    backgroundColor: ProfileLayout.chipBg,
                    side: BorderSide(
                      color: ProfileLayout.deepLavender.withValues(alpha: 0.15),
                    ),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    onPressed: onInterestTap == null
                        ? null
                        : () => onInterestTap!(interest),
                  );
                }),
                if (interests.length > 5)
                  Text(
                    '+${interests.length - 5}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: ProfileLayout.textMuted,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
          ] else if (fitnessTag.isNotEmpty) ...[
            Text(
              fitnessTag,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: ProfileLayout.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
          ],
          Row(
            children: [
              if (city.isNotEmpty) ...[
                Icon(Icons.location_on_outlined,
                    size: 14, color: ProfileLayout.textMuted),
                const SizedBox(width: 4),
                Text(
                  city,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: ProfileLayout.textSecondary,
                  ),
                ),
              ],
              if (age != null) ...[
                if (city.isNotEmpty) const SizedBox(width: 12),
                Text(
                  '$age yrs',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: ProfileLayout.textSecondary,
                  ),
                ),
              ],
            ],
          ),
          if (showHealthNotes && healthNotes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Theme(
              data: Theme.of(context).copyWith(
                dividerColor: Colors.transparent,
                splashColor: ProfileLayout.lavender.withValues(alpha: 0.1),
              ),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                iconColor: ProfileLayout.deepLavender,
                collapsedIconColor: ProfileLayout.textSecondary,
                title: Text(
                  'Notes',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ProfileLayout.deepLavender,
                  ),
                ),
                children: healthNotes
                    .map(
                      (n) => Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            n,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: ProfileLayout.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
