import 'package:halo/screens/profile/core/profile_type.dart';
import 'package:halo/screens/profile/core/profile_modules.dart';

class WellnessProfileConfig {
  static const ProfileKind kind = ProfileKind.wellness;

  static const List<String> sectionIds = <String>[
    'products',
    'services',
    'booking',
    'staff',
    'events',
    'reviews',
    'analytics',
    'recent_posts',
    'gallery',
    'amenities',
    'membership',
    'offers',
    'awards',
    'location',
  ];

  static const Map<String, String> moduleLabels = {
    'products': 'Popular Products',
    'services': 'Services Offered',
    'booking': 'Bookings',
    'staff': 'Our Team',
    'events': 'Fitness Events',
    'reviews': 'Reviews',
    'analytics': 'Analytics',
    'recent_posts': 'Recent Posts',
    'gallery': 'Facility Gallery',
    'amenities': 'Amenities',
    'membership': 'Membership Plans',
    'offers': 'Special Offers',
    'awards': 'Awards & Certifications',
    'location': 'Location',
  };

  static bool isSectionEnabled(ProfileModules modules, String sectionId) {
    return modules.isEnabled(sectionId);
  }
}
