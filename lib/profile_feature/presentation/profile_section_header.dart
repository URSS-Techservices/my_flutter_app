import 'package:flutter/material.dart';
import 'package:halo/profile_feature/presentation/profile_style.dart';

/// "Recent Posts            See All" row used above each profile section.
class ProfileSectionHeader extends StatelessWidget {
  const ProfileSectionHeader({
    super.key,
    required this.title,
    this.onSeeAll,
    this.actionLabel = 'See All',
  });

  final String title;
  final VoidCallback? onSeeAll;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          ProfileStyle.sideGap, 20, ProfileStyle.sideGap - 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: ProfileStyle.name.copyWith(fontSize: 18)),
          ),
          if (onSeeAll != null)
            ProfileTextLink(label: actionLabel, onTap: onSeeAll!),
        ],
      ),
    );
  }
}

/// Small "See All ›" style link used across the profile, so every action
/// link looks the same.
class ProfileTextLink extends StatelessWidget {
  const ProfileTextLink({
    super.key,
    required this.label,
    required this.onTap,
    this.icon = Icons.chevron_right,
  });

  final String label;
  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: ProfileStyle.small.copyWith(
                color: ProfileStyle.link,
                fontWeight: FontWeight.w600,
              ),
            ),
            Icon(icon, size: 18, color: ProfileStyle.link),
          ],
        ),
      ),
    );
  }
}

/// Grey message shown when a section has nothing yet.
class ProfileEmptyMessage extends StatelessWidget {
  const ProfileEmptyMessage({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: ProfileStyle.sideGap),
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ProfileStyle.divider),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: ProfileStyle.mutedText),
          const SizedBox(height: 8),
          Text(text, style: ProfileStyle.small),
        ],
      ),
    );
  }
}
