import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/screens/profile/profile_theme.dart';
import 'package:halo/screens/profile/widgets/common/profile_empty_state_rich.dart';

class AspirantAchievementsSection extends StatelessWidget {
  final List<String> badges;
  final bool isOwnProfile;
  final VoidCallback? onOpenModules;

  const AspirantAchievementsSection({
    super.key,
    required this.badges,
    required this.isOwnProfile,
    this.onOpenModules,
  });

  @override
  Widget build(BuildContext context) {
    if (badges.isEmpty && !isOwnProfile) return const SizedBox.shrink();

    if (badges.isEmpty && isOwnProfile) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: ProfileEmptyStateRich(
          text: 'Earn badges as you explore Halo',
          icon: Icons.emoji_events_outlined,
          actionLabel: 'Enable in Profile Sections',
          onAction: onOpenModules,
          card: true,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Achievements & Badges',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isOwnProfile)
                Flexible(
                  child: Text(
                    'Auto-unlocks as you use Halo',
                    style: GoogleFonts.poppins(fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: badges
                .map(
                  (b) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: ProfileLayout.chipBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.emoji_events, size: 16, color: ProfileLayout.deepLavender),
                        const SizedBox(width: 4),
                        Text(b, style: GoogleFonts.poppins(fontSize: 11)),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}
