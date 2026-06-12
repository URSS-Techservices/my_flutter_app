import 'package:halo/models/aspirant_profile_model.dart';
import 'package:halo/screens/profile/core/profile_type.dart';

/// Metadata for aspirant-specific modular sections (ordering / feature flags).
class AspirantProfileConfig {
  static const ProfileKind kind = ProfileKind.aspirant;

  static const List<String> sectionIds = <String>[
    'achievements',
    'recent_activities',
    'learning_resources',
    'activity_stats',
    'progress_tracking',
    'workout_calendar',
    'fitness_goals',
    'workout_streak',
    'personal_records',
    'weekly_progress',
  ];

  static const Map<String, String> moduleLabels = {
    'fitnessGoals': 'Fitness Goals',
    'recentActivities': 'Recent Activities',
    'activityStats': 'Activity Stats',
    'progressTracking': 'Progress Tracking',
    'workoutCalendar': 'Workout Calendar',
    'workoutStreak': 'Workout Streak',
    'personalRecords': 'Personal Records',
    'weeklyProgress': 'Weekly Progress',
    'learningResources': 'Learning Resources',
    'achievements': 'Achievements & Badges',
  };

  static const List<String> moduleKeys = [
    'fitnessGoals',
    'recentActivities',
    'activityStats',
    'progressTracking',
    'workoutCalendar',
    'workoutStreak',
    'personalRecords',
    'weeklyProgress',
    'learningResources',
    'achievements',
  ];

  static bool isModuleEnabled(
    AspirantProfileModules modules,
    String key,
  ) {
    switch (key) {
      case 'fitnessGoals':
        return modules.fitnessGoals;
      case 'recentActivities':
        return modules.recentActivities;
      case 'activityStats':
        return modules.activityStats;
      case 'progressTracking':
        return modules.progressTracking;
      case 'workoutCalendar':
        return modules.workoutCalendar;
      case 'workoutStreak':
        return modules.workoutStreak;
      case 'personalRecords':
        return modules.personalRecords;
      case 'weeklyProgress':
        return modules.weeklyProgress;
      case 'learningResources':
        return modules.learningResources;
      case 'achievements':
        return modules.achievements;
      default:
        return false;
    }
  }

  static bool isSectionEnabled(
    AspirantProfileModules modules,
    String sectionId,
  ) {
    switch (sectionId) {
      case 'achievements':
        return modules.achievements;
      case 'recent_activities':
        return modules.recentActivities;
      case 'learning_resources':
        return modules.learningResources;
      case 'activity_stats':
        return modules.activityStats;
      case 'progress_tracking':
        return modules.progressTracking;
      case 'workout_calendar':
        return modules.workoutCalendar;
      case 'fitness_goals':
        return modules.fitnessGoals;
      case 'workout_streak':
        return modules.workoutStreak;
      case 'personal_records':
        return modules.personalRecords;
      case 'weekly_progress':
        return modules.weeklyProgress;
      default:
        return false;
    }
  }
}
