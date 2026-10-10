import 'package:halo/profile_feature/domain/aspirant_fitness_stats.dart';
import 'package:halo/profile_feature/domain/profile_basics.dart';

/// Aspirant-only fields on top of the shared [ProfileBasics].
///
/// Workouts are added here as their section is built.
class AspirantProfile {
  final ProfileBasics basics;
  final String primaryCategory;
  final AspirantFitnessStats fitnessStats;

  const AspirantProfile({
    required this.basics,
    required this.primaryCategory,
    required this.fitnessStats,
  });

  factory AspirantProfile.fromMap(String id, Map<String, dynamic> map) {
    return AspirantProfile(
      basics: ProfileBasics.fromMap(id, map),
      primaryCategory: (map['primaryCategory'] ?? '').toString(),
      fitnessStats: AspirantFitnessStats.fromMap(map['fitnessStats']),
    );
  }
}
