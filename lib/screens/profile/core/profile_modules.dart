import 'package:halo/screens/profile/configs/guru_profile_config.dart';
import 'package:halo/screens/profile/configs/wellness_profile_config.dart';

/// Shared profile section toggles for guru and wellness accounts.
class ProfileModules {
  final Map<String, bool> flags;

  const ProfileModules(this.flags);

  factory ProfileModules.fromMap(Map<String, dynamic>? raw) {
    if (raw == null || raw.isEmpty) {
      return ProfileModules.defaultEnabled();
    }
    final merged = Map<String, bool>.from(ProfileModules.defaultEnabled().flags);
    for (final entry in raw.entries) {
      merged[entry.key] = entry.value == true;
    }
    return ProfileModules(merged);
  }

  factory ProfileModules.defaultEnabled() {
    return ProfileModules({
      for (final id in GuruProfileConfig.sectionIds) id: true,
      for (final id in WellnessProfileConfig.sectionIds) id: true,
      // Wellness profile-tab extras
      'gallery': true,
      'amenities': true,
      'membership': true,
      'offers': true,
      'awards': true,
      'location': true,
      // Guru profile-tab extras
      'success_stories': true,
      'video_tutorials': true,
      'certifications': true,
      'social_links': true,
    });
  }

  Map<String, dynamic> toMap() => Map<String, dynamic>.from(flags);

  bool isEnabled(String sectionId) => flags[sectionId] ?? true;
}
