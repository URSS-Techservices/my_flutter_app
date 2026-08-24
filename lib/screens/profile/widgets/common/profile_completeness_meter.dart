import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/screens/profile/core/profile_type.dart';
import 'package:halo/screens/profile/profile_theme.dart';

/// Nudges owners to complete role-specific profile fields.
class ProfileCompletenessMeter extends StatelessWidget {
  final ProfileKind kind;
  final Map<String, dynamic> userData;
  final VoidCallback? onTapImprove;

  const ProfileCompletenessMeter({
    super.key,
    required this.kind,
    required this.userData,
    this.onTapImprove,
  });

  int _score() {
    var filled = 0;
    var total = 0;

    void check(String? value) {
      total++;
      if (value != null && value.trim().isNotEmpty) filled++;
    }

    check(userData['bio']?.toString());
    check(userData['profilePhoto']?.toString() ?? userData['profilePic']?.toString());
    check(userData['coverPhoto']?.toString());
    check(userData['username']?.toString());

    switch (kind) {
      case ProfileKind.aspirant:
        check(userData['primaryCategory']?.toString());
        check(userData['city']?.toString());
        final interests = userData['interests'];
        total++;
        if (interests is List && interests.isNotEmpty) filled++;
        final goals = userData['fitnessGoals'];
        total++;
        if (goals is List && goals.isNotEmpty) filled++;
        break;
      case ProfileKind.guru:
        check(userData['primaryCategory']?.toString());
        check(userData['city']?.toString());
        final specs = userData['specialties'];
        total++;
        if (specs is List && specs.isNotEmpty) filled++;
        break;
      case ProfileKind.wellness:
        check(userData['category']?.toString() ?? userData['wellness_category']?.toString());
        check(userData['city']?.toString() ?? userData['location']?.toString());
        final services = userData['services'];
        total++;
        if (services is List && services.isNotEmpty) filled++;
        break;
    }

    if (total == 0) return 0;
    return ((filled / total) * 100).round().clamp(0, 100);
  }

  @override
  Widget build(BuildContext context) {
    final score = _score();
    if (score >= 100) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Material(
        color: ProfileLayout.chipBg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTapImprove,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Profile $score% complete',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (onTapImprove != null)
                      Text(
                        'Improve',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: ProfileLayout.deepLavender,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: score / 100,
                    minHeight: 6,
                    backgroundColor: Colors.white,
                    valueColor: AlwaysStoppedAnimation(ProfileLayout.deepLavender),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
