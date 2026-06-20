import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/screens/profile/profile_theme.dart';

/// Collapsible hub combining progress, streak, records, and weekly chart entry points.
class AspirantProgressHub extends StatelessWidget {
  final Map<String, dynamic> fitnessStats;
  final List<Map<String, dynamic>> personalRecords;
  final List<Map<String, dynamic>> weeklyProgress;
  final int currentStreak;
  final int longestStreak;
  final VoidCallback? onEditProgress;
  final VoidCallback? onAddRecord;
  final bool isOwnProfile;

  const AspirantProgressHub({
    super.key,
    required this.fitnessStats,
    required this.personalRecords,
    required this.weeklyProgress,
    required this.currentStreak,
    required this.longestStreak,
    this.onEditProgress,
    this.onAddRecord,
    this.isOwnProfile = false,
  });

  @override
  Widget build(BuildContext context) {
    final weight = fitnessStats['currentWeight'];
    final targetWeight = fitnessStats['targetWeight'];
    final steps = fitnessStats['steps'] ?? 0;
    final workouts = fitnessStats['workouts'] ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights_outlined, color: ProfileLayout.deepLavender),
                const SizedBox(width: 8),
                Text(
                  'My Journey',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (isOwnProfile && onEditProgress != null)
                  TextButton(onPressed: onEditProgress, child: const Text('Update')),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _statTile('Streak', '$currentStreak days', Icons.local_fire_department),
                _statTile('Best', '$longestStreak days', Icons.emoji_events_outlined),
                _statTile('Workouts', '$workouts', Icons.fitness_center),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _statTile('Steps', '$steps', Icons.directions_walk),
                _statTile('Weight', '${weight ?? '—'} kg', Icons.monitor_weight_outlined),
                _statTile('Target', '${targetWeight ?? '—'} kg', Icons.flag_outlined),
              ],
            ),
            if (personalRecords.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Personal records', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...personalRecords.take(3).map(
                (r) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.military_tech, color: ProfileLayout.lavender, size: 20),
                  title: Text(r['name']?.toString() ?? 'Record'),
                  trailing: Text(r['value']?.toString() ?? ''),
                ),
              ),
            ],
            if (isOwnProfile && onAddRecord != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onAddRecord,
                  icon: const Icon(Icons.add),
                  label: const Text('Add record'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statTile(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: ProfileLayout.lavender),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
          Text(label, style: GoogleFonts.poppins(fontSize: 11, color: ProfileLayout.textSecondary)),
        ],
      ),
    );
  }
}
