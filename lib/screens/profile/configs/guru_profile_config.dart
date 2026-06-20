import 'package:halo/screens/profile/core/profile_type.dart';
import 'package:halo/screens/profile/core/profile_modules.dart';

class GuruProfileConfig {
  static const ProfileKind kind = ProfileKind.guru;

  static const List<String> sectionIds = <String>[
    'booking',
    'classes',
    'students',
    'earnings',
    'analytics',
    'recent_posts',
    'reviews',
    'programs',
    'success_stories',
    'video_tutorials',
    'certifications',
    'social_links',
  ];

  static const Map<String, String> moduleLabels = {
    'booking': 'Booking',
    'classes': 'Classes & Batches',
    'students': 'Students',
    'earnings': 'Earnings',
    'analytics': 'Analytics',
    'recent_posts': 'Recent Posts',
    'reviews': 'Reviews & Ratings',
    'programs': 'Training Programs',
    'success_stories': 'Success Stories',
    'video_tutorials': 'Video Tutorials',
    'certifications': 'Certifications',
    'social_links': 'Social Links',
  };

  static bool isSectionEnabled(ProfileModules modules, String sectionId) {
    return modules.isEnabled(sectionId);
  }
}
