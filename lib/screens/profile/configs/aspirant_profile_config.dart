import 'package:halo/screens/profile/core/profile_type.dart';

/// Metadata for aspirant-specific modular sections (ordering / feature flags).
class AspirantProfileConfig {
  static const ProfileKind kind = ProfileKind.aspirant;

  /// Section keys for aspirant-only blocks (fitness, activities, resources, etc.).
  static const List<String> sectionIds = <String>[
    'fitness_goals',
    'recent_posts',
    'activities',
    'learning_resources',
    'suggested_coaches',
    'suggested_wellness',
    'suggested_aspirants',
  ];
}
