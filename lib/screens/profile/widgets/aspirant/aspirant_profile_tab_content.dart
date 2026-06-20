import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/models/aspirant_profile_model.dart';
import 'package:halo/screens/profile/profile_theme.dart';
import 'package:halo/screens/profile/widgets/aspirant/aspirant_achievements_section.dart';
import 'package:halo/screens/profile/widgets/aspirant/aspirant_discovery_panel.dart';
import 'package:halo/screens/profile/widgets/aspirant/aspirant_fitness_goals_section.dart';
import 'package:halo/screens/profile/widgets/aspirant/aspirant_my_circle_section.dart';
import 'package:halo/screens/profile/widgets/aspirant/aspirant_my_bookings_section.dart';
import 'package:halo/screens/profile/widgets/aspirant/aspirant_progress_hub.dart';
import 'package:halo/screens/profile/widgets/aspirant/aspirant_recent_activities_section.dart';
import 'package:halo/screens/profile/widgets/aspirant/aspirant_recent_posts_grid.dart';
import 'package:halo/screens/profile/widgets/aspirant/aspirant_record_display_utils.dart';
import 'package:halo/screens/profile/widgets/common/profile_empty_state_rich.dart';
import 'package:halo/screens/profile/widgets/common/profile_section_gate.dart';

/// Composes the aspirant profile tab: discovery, optional modules, and fitness sections.
class AspirantProfileTabContent extends StatelessWidget {
  final String profileUserId;
  final String? currentUserId;
  final bool isOwnProfile;
  final bool isPrivate;
  final bool isFollowing;
  final List<String> interests;
  final String? primaryCategory;
  final List<Map<String, dynamic>> eventsChallenges;
  final Map<String, String> socialLinks;
  final List<String> badges;
  final List<Map<String, dynamic>> lastWorkouts;
  final List<Map<String, dynamic>> fitnessArticles;
  final Map<String, dynamic> fitnessStats;
  final List<FitnessGoalItem> fitnessGoals;
  final List<Map<String, dynamic>> personalRecords;
  final List<Map<String, dynamic>> weeklyProgressData;
  final List<int> workoutCalendarDays;
  final bool Function(String moduleId) isSectionEnabled;
  final String Function(int month) monthName;
  final Set<int> Function({
    required int year,
    required int month,
    required List<Map<String, dynamic>> lastWorkouts,
    required List<int> storedCalendarDays,
  }) workoutDaysForMonth;
  final void Function(String interest) onOpenInterestExplore;
  final Future<void> Function(String platform, String url) onOpenSocialLink;
  final VoidCallback onEditEvents;
  final VoidCallback onEditSocialLinks;
  final VoidCallback? onOpenProfileModules;
  final VoidCallback onEditActivities;
  final VoidCallback onEditFitnessStats;
  final void Function(Map<String, dynamic> article) onOpenArticle;
  final VoidCallback onViewFullProgress;
  final void Function(String type) onEditProgress;
  final VoidCallback onAddGoal;
  final void Function(FitnessGoalItem goal) onEditGoal;
  final void Function(FitnessGoalItem goal) onDeleteGoal;
  final void Function(FitnessGoalItem goal) onFindCoachesForGoal;
  final void Function(FitnessGoalItem goal) onFindWellnessForGoal;
  final void Function(int index, Map<String, dynamic> record) onEditPersonalRecord;
  final VoidCallback onAddWorkoutFromCalendar;
  final String? Function(Map<String, dynamic> data) postImageResolver;
  final void Function(String postId) onTapPost;
  final VoidCallback onTapViewAllPosts;

  const AspirantProfileTabContent({
    super.key,
    required this.profileUserId,
    required this.currentUserId,
    required this.isOwnProfile,
    required this.isPrivate,
    required this.isFollowing,
    required this.interests,
    required this.primaryCategory,
    required this.eventsChallenges,
    required this.socialLinks,
    required this.badges,
    required this.lastWorkouts,
    required this.fitnessArticles,
    required this.fitnessStats,
    required this.fitnessGoals,
    required this.personalRecords,
    required this.weeklyProgressData,
    required this.workoutCalendarDays,
    required this.isSectionEnabled,
    required this.monthName,
    required this.workoutDaysForMonth,
    required this.onOpenInterestExplore,
    required this.onOpenSocialLink,
    required this.onEditEvents,
    required this.onEditSocialLinks,
    this.onOpenProfileModules,
    required this.onEditActivities,
    required this.onEditFitnessStats,
    required this.onOpenArticle,
    required this.onViewFullProgress,
    required this.onEditProgress,
    required this.onAddGoal,
    required this.onEditGoal,
    required this.onDeleteGoal,
    required this.onFindCoachesForGoal,
    required this.onFindWellnessForGoal,
    required this.onEditPersonalRecord,
    required this.onAddWorkoutFromCalendar,
    required this.postImageResolver,
    required this.onTapPost,
    required this.onTapViewAllPosts,
  });

  @override
  Widget build(BuildContext context) {
    final currentStreak = (fitnessStats['currentStreak'] as num?)?.toInt() ?? 0;
    final longestStreak = (fitnessStats['longestStreak'] as num?)?.toInt() ?? 0;

    return ColoredBox(
      color: ProfileLayout.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspirantDiscoveryPanel(
            profileUserId: profileUserId,
            currentUserId: currentUserId,
            interests: interests,
            primaryCategory: primaryCategory,
            isOwnProfile: isOwnProfile,
            eventsChallenges: eventsChallenges,
            socialLinks: socialLinks,
            onEditEvents: onEditEvents,
            onEditSocialLinks: onEditSocialLinks,
            onOpenInterestExplore: onOpenInterestExplore,
            onOpenSocialLink: onOpenSocialLink,
          ),
          AspirantMyCircleSection(
            aspirantUserId: profileUserId,
            isOwnProfile: isOwnProfile,
          ),
          AspirantMyBookingsSection(
            aspirantUserId: profileUserId,
            isOwnProfile: isOwnProfile,
          ),
          if (isOwnProfile)
            AspirantRecentPostsGrid(
              isPrivate: isPrivate,
              isFollowing: isFollowing,
              isOwnProfile: isOwnProfile,
              profileUserId: profileUserId,
              accentColor: ProfileLayout.lavender,
              imageResolver: postImageResolver,
              onTapPost: onTapPost,
              onTapViewAll: onTapViewAllPosts,
            ),
          ProfileSectionGate(
            enabled: isSectionEnabled('progress_tracking') ||
                isSectionEnabled('workout_streak') ||
                isSectionEnabled('personal_records'),
            child: _progressHub(currentStreak, longestStreak),
          ),
          ProfileSectionGate(
            enabled: isSectionEnabled('achievements'),
            child: AspirantAchievementsSection(
              badges: badges,
              isOwnProfile: isOwnProfile,
              onOpenModules: onOpenProfileModules,
            ),
          ),
          ProfileSectionGate(
            enabled: isSectionEnabled('recent_activities'),
            child: AspirantRecentActivitiesSection(
              activities: lastWorkouts,
              isOwnProfile: isOwnProfile,
              onEdit: isOwnProfile ? onEditActivities : null,
            ),
          ),
          ProfileSectionGate(
            enabled: isSectionEnabled('learning_resources'),
            child: _fitnessArticles(),
          ),
          ProfileSectionGate(
            enabled: isSectionEnabled('activity_stats'),
            child: _fitnessStats(),
          ),
          ProfileSectionGate(
            enabled: isSectionEnabled('progress_tracking'),
            child: _progressTracking(),
          ),
          ProfileSectionGate(
            enabled: isSectionEnabled('workout_calendar'),
            child: _workoutCalendar(),
          ),
          ProfileSectionGate(
            enabled: isSectionEnabled('fitness_goals'),
            child: _fitnessGoals(),
          ),
          ProfileSectionGate(
            enabled: isSectionEnabled('workout_streak'),
            child: _workoutStreak(currentStreak, longestStreak),
          ),
          ProfileSectionGate(
            enabled: isSectionEnabled('personal_records'),
            child: _personalRecords(),
          ),
          ProfileSectionGate(
            enabled: isSectionEnabled('weekly_progress'),
            child: _weeklyProgress(),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _progressHub(int currentStreak, int longestStreak) {
    final showHub = isOwnProfile ||
        (fitnessStats.isNotEmpty && (fitnessStats['workouts'] ?? 0) != 0) ||
        personalRecords.isNotEmpty;
    if (!showHub) return const SizedBox.shrink();

    return AspirantProgressHub(
      fitnessStats: fitnessStats,
      personalRecords: personalRecords,
      weeklyProgress: weeklyProgressData,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      isOwnProfile: isOwnProfile,
      onEditProgress: isOwnProfile ? () => onEditProgress('weight') : null,
      onAddRecord: isOwnProfile ? () => onEditPersonalRecord(-1, {}) : null,
    );
  }

  Widget _fitnessArticles() {
    if (fitnessArticles.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Learning Resources', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          ...fitnessArticles.map(
            (a) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(a['title']?.toString() ?? '', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              subtitle: Text(a['source']?.toString() ?? '', style: GoogleFonts.poppins(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => onOpenArticle(a),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fitnessStats() {
    final steps = fitnessStats['steps'] ?? 0;
    final calories = fitnessStats['caloriesBurned'] ?? 0;
    final workouts = fitnessStats['workouts'] ?? 0;
    if (steps == 0 && calories == 0 && workouts == 0 && !isOwnProfile) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Activity Stats', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
              if (isOwnProfile)
                TextButton.icon(onPressed: onEditFitnessStats, icon: const Icon(Icons.edit, size: 18), label: const Text('Edit')),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _statCard('Steps', steps.toString(), 'Today'),
              _statCard('Calories', calories.toString(), 'Today'),
              _statCard('Sessions', workouts.toString(), 'This week'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statCard(String title, String value, String subtitle) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: GoogleFonts.poppins(fontSize: 11)),
            const SizedBox(height: 6),
            Text(value, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(subtitle, style: GoogleFonts.poppins(fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _progressTracking() {
    if (!isOwnProfile) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Progress Tracking', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                TextButton(onPressed: onViewFullProgress, child: const Text('View')),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => onEditProgress('weight'),
                    child: _metricCard(
                      'Weight',
                      '${fitnessStats['currentWeight'] ?? 0} kg',
                      'Goal: ${fitnessStats['targetWeight'] ?? 0} kg',
                      Icons.monitor_weight,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => onEditProgress('bodyFat'),
                    child: _metricCard(
                      'Body Fat',
                      '${fitnessStats['bodyFat'] ?? 0}%',
                      'Target: ${fitnessStats['targetBodyFat'] ?? 0}%',
                      Icons.analytics,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricCard(String title, String value, String subtitle, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ProfileLayout.lavender.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ProfileLayout.lavender.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, size: 18, color: ProfileLayout.lavender), const SizedBox(width: 6), Text(title, style: GoogleFonts.poppins(fontSize: 12))]),
          const SizedBox(height: 8),
          Text(value, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: ProfileLayout.deepLavender)),
          Text(subtitle, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _workoutCalendar() {
    if (!isOwnProfile) return const SizedBox.shrink();
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final workoutDays = workoutDaysForMonth(
      year: now.year,
      month: now.month,
      lastWorkouts: lastWorkouts,
      storedCalendarDays: workoutCalendarDays,
    );

    if (workoutDays.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: ProfileEmptyStateRich(
          text: 'Log activities to see them on your calendar',
          icon: Icons.calendar_today_outlined,
          actionLabel: 'Add Activity',
          onAction: onAddWorkoutFromCalendar,
          card: true,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Workout Calendar', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('${monthName(now.month)} ${now.year}', style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: List.generate(daysInMonth, (index) {
                final day = index + 1;
                final isWorkoutDay = workoutDays.contains(day);
                final isToday = day == now.day;
                return Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isToday
                        ? ProfileLayout.lavender
                        : isWorkoutDay
                            ? ProfileLayout.lavender.withValues(alpha: 0.2)
                            : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$day',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                      color: isToday ? Colors.white : isWorkoutDay ? ProfileLayout.lavender : Colors.grey.shade600,
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fitnessGoals() {
    if (!isOwnProfile && fitnessGoals.isEmpty) return const SizedBox.shrink();
    return AspirantFitnessGoalsSection(
      goals: fitnessGoals,
      isOwnProfile: isOwnProfile,
      onAddGoal: onAddGoal,
      onEditGoal: onEditGoal,
      onDeleteGoal: onDeleteGoal,
      onFindCoaches: onFindCoachesForGoal,
      onFindWellness: onFindWellnessForGoal,
      accentColor: ProfileLayout.lavender,
      accentDarkColor: ProfileLayout.deepLavender,
    );
  }

  Widget _workoutStreak(int currentStreak, int longestStreak) {
    if (currentStreak == 0 && longestStreak == 0 && !isOwnProfile) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [ProfileLayout.lavender.withValues(alpha: 0.25), ProfileLayout.chipBg]),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.local_fire_department, color: ProfileLayout.deepLavender, size: 32),
                const SizedBox(width: 12),
                Text('$currentStreak', style: GoogleFonts.poppins(fontSize: 36, fontWeight: FontWeight.bold, color: ProfileLayout.deepLavender)),
                const SizedBox(width: 8),
                Text('Day Streak!', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: ProfileLayout.deepLavender)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              longestStreak > 0 ? 'Keep it up! Your longest streak is $longestStreak days' : 'Start logging activities to build your streak',
              style: GoogleFonts.poppins(fontSize: 13, color: ProfileLayout.deepLavender.withValues(alpha: 0.85)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _personalRecords() {
    if (personalRecords.isEmpty && !isOwnProfile) return const SizedBox.shrink();
    if (personalRecords.isEmpty && isOwnProfile) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: ProfileEmptyStateRich(
          text: 'Track your personal bests',
          icon: Icons.emoji_events_outlined,
          actionLabel: 'Add Record',
          onAction: () => onEditPersonalRecord(-1, {}),
          card: true,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Personal Records', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SizedBox(
            height: 130,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: personalRecords.length,
              itemBuilder: (context, index) {
                final record = personalRecords[index];
                final color = record['color'] is Color
                    ? record['color'] as Color
                    : aspirantRecordColorFromString(record['color']?.toString() ?? 'blue');
                final icon = record['icon'] is IconData
                    ? record['icon'] as IconData
                    : aspirantRecordIconFromString(record['icon']?.toString() ?? 'fitness_center');
                return GestureDetector(
                  onTap: isOwnProfile ? () => onEditPersonalRecord(index, record) : null,
                  child: Container(
                    width: 140,
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(icon, color: color, size: 24),
                        const SizedBox(height: 6),
                        Text(record['name']?.toString() ?? 'Record', style: GoogleFonts.poppins(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(record['value']?.toString() ?? '0', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _weeklyProgress() {
    if (!isOwnProfile) return const SizedBox.shrink();
    if (weeklyProgressData.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: ProfileEmptyStateRich(text: 'Log weekly activity to see your progress chart', icon: Icons.bar_chart_outlined, card: true),
      );
    }

    final maxCalories = weeklyProgressData
        .map((d) => (d['calories'] as num?)?.toInt() ?? 0)
        .fold<int>(0, (a, b) => a > b ? a : b);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Weekly Progress', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: weeklyProgressData.map((data) {
                final calories = (data['calories'] as num?)?.toInt() ?? 0;
                final height = maxCalories > 0 ? (calories / maxCalories * 100).clamp(0.0, 100.0) : 0.0;
                return Column(
                  children: [
                    Container(
                      width: 32,
                      height: height,
                      decoration: BoxDecoration(
                        color: calories > 0 ? ProfileLayout.lavender : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(data['day']?.toString() ?? '', style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
                    Text('$calories', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600)),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
