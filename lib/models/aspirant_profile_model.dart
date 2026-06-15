import 'package:cloud_firestore/cloud_firestore.dart';

/// Aspirant-specific profile fields and optional module toggles.
class AspirantProfileModules {
  final bool fitnessGoals;
  final bool recentActivities;
  final bool activityStats;
  final bool progressTracking;
  final bool workoutCalendar;
  final bool workoutStreak;
  final bool personalRecords;
  final bool weeklyProgress;
  final bool learningResources;
  final bool achievements;

  const AspirantProfileModules({
    this.fitnessGoals = true,
    this.recentActivities = true,
    this.activityStats = false,
    this.progressTracking = false,
    this.workoutCalendar = false,
    this.workoutStreak = false,
    this.personalRecords = false,
    this.weeklyProgress = false,
    this.learningResources = false,
    this.achievements = true,
  });

  factory AspirantProfileModules.fromMap(Map<String, dynamic>? raw) {
    if (raw == null || raw.isEmpty) return const AspirantProfileModules();
    bool b(String key, bool fallback) {
      final v = raw[key];
      if (v is bool) return v;
      return fallback;
    }
    return AspirantProfileModules(
      fitnessGoals: b('fitnessGoals', true),
      recentActivities: b('recentActivities', true),
      activityStats: b('activityStats', false),
      progressTracking: b('progressTracking', false),
      workoutCalendar: b('workoutCalendar', false),
      workoutStreak: b('workoutStreak', false),
      personalRecords: b('personalRecords', false),
      weeklyProgress: b('weeklyProgress', false),
      learningResources: b('learningResources', false),
      achievements: b('achievements', true),
    );
  }

  Map<String, dynamic> toMap() => {
        'fitnessGoals': fitnessGoals,
        'recentActivities': recentActivities,
        'activityStats': activityStats,
        'progressTracking': progressTracking,
        'workoutCalendar': workoutCalendar,
        'workoutStreak': workoutStreak,
        'personalRecords': personalRecords,
        'weeklyProgress': weeklyProgress,
        'learningResources': learningResources,
        'achievements': achievements,
      };

  AspirantProfileModules copyWith({
    bool? fitnessGoals,
    bool? recentActivities,
    bool? activityStats,
    bool? progressTracking,
    bool? workoutCalendar,
    bool? workoutStreak,
    bool? personalRecords,
    bool? weeklyProgress,
    bool? learningResources,
    bool? achievements,
  }) {
    return AspirantProfileModules(
      fitnessGoals: fitnessGoals ?? this.fitnessGoals,
      recentActivities: recentActivities ?? this.recentActivities,
      activityStats: activityStats ?? this.activityStats,
      progressTracking: progressTracking ?? this.progressTracking,
      workoutCalendar: workoutCalendar ?? this.workoutCalendar,
      workoutStreak: workoutStreak ?? this.workoutStreak,
      personalRecords: personalRecords ?? this.personalRecords,
      weeklyProgress: weeklyProgress ?? this.weeklyProgress,
      learningResources: learningResources ?? this.learningResources,
      achievements: achievements ?? this.achievements,
    );
  }
}

/// Parsed fitness goal with optional progress (0.0–1.0).
class FitnessGoalItem {
  final String name;
  final double progress;

  const FitnessGoalItem({required this.name, this.progress = 0});

  Map<String, dynamic> toMap() => {'name': name, 'progress': progress};

  factory FitnessGoalItem.fromDynamic(dynamic raw) {
    if (raw is String) {
      return FitnessGoalItem(name: raw.trim());
    }
    if (raw is Map) {
      final name = (raw['name'] ?? '').toString().trim();
      final p = (raw['progress'] as num?)?.toDouble() ?? 0;
      return FitnessGoalItem(
        name: name,
        progress: p.clamp(0.0, 1.0),
      );
    }
    return FitnessGoalItem(name: raw.toString());
  }
}

List<FitnessGoalItem> parseFitnessGoals(dynamic raw) {
  if (raw is! List) return [];
  return raw.map(FitnessGoalItem.fromDynamic).where((g) => g.name.isNotEmpty).toList();
}

List<Map<String, dynamic>> parseRecordList(dynamic raw) {
  if (raw is! List) return [];
  return raw
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
}

List<Map<String, dynamic>> parseWeeklyProgress(dynamic raw) {
  if (raw is! List) return [];
  return raw
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
}

/// Derive workout calendar day numbers from activities or stored calendar.
Set<int> workoutDaysForMonth({
  required int year,
  required int month,
  List<Map<String, dynamic>>? lastWorkouts,
  List<int>? storedCalendarDays,
}) {
  if (storedCalendarDays != null && storedCalendarDays.isNotEmpty) {
    return storedCalendarDays.toSet();
  }
  final days = <int>{};
  for (final w in lastWorkouts ?? const []) {
    final date = w['date'];
    DateTime? dt;
    if (date is DateTime) {
      dt = date;
    } else if (date is Timestamp) {
      dt = date.toDate();
    }
    if (dt != null && dt.year == year && dt.month == month) {
      days.add(dt.day);
    }
  }
  return days;
}
