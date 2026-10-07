import 'package:halo/profile_feature/domain/aspirant_fitness_stats.dart';
import 'package:halo/profile_feature/domain/profile_basics.dart';

/// Everything the aspirant profile page shows.
///
/// Workouts and activity are added here as their sections are built.
class AspirantProfile {
  final ProfileBasics basics;
  final String primaryCategory;
  final List<String> interests;
  final String website;

  /// Platform key (see `SocialPlatform.key`) → link. May also hold keys the
  /// old pages saved (e.g. telegram); those are kept when saving.
  final Map<String, String> socialLinks;
  final AspirantFitnessStats fitnessStats;

  const AspirantProfile({
    required this.basics,
    required this.primaryCategory,
    required this.interests,
    required this.website,
    required this.socialLinks,
    required this.fitnessStats,
  });

  factory AspirantProfile.fromMap(String id, Map<String, dynamic> map) {
    final interests = map['interests'];
    final links = map['socialLinks'];
    return AspirantProfile(
      basics: ProfileBasics.fromMap(id, map),
      primaryCategory: (map['primaryCategory'] ?? '').toString(),
      interests: interests is List
          ? interests.map((e) => e.toString()).toList()
          : const [],
      website: (map['website'] ?? '').toString().trim(),
      socialLinks: links is Map
          ? {
              for (final e in links.entries)
                if (e.value != null && e.value.toString().trim().isNotEmpty)
                  e.key.toString(): e.value.toString().trim(),
            }
          : const {},
      fitnessStats: AspirantFitnessStats.fromMap(map['fitnessStats']),
    );
  }
}
