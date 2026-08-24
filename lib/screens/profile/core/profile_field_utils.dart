/// Unified read/write helpers for Firestore user profile fields that drift
/// across account types (`full_name` vs `name`, `profilePhoto` vs `profilePic`).
class ProfileFieldUtils {
  ProfileFieldUtils._();

  static String displayName(Map<String, dynamic> data) {
    for (final key in ['full_name', 'name', 'business_name']) {
      final v = data[key]?.toString().trim();
      if (v != null && v.isNotEmpty) return v;
    }
    return '';
  }

  static String profilePhotoUrl(Map<String, dynamic> data) {
    for (final key in ['profilePhoto', 'profilePic', 'photoURL']) {
      final v = data[key]?.toString().trim();
      if (v != null && v.isNotEmpty) return v;
    }
    return '';
  }

  static String coverPhotoUrl(Map<String, dynamic> data) {
    final v = data['coverPhoto']?.toString().trim();
    return (v != null && v.isNotEmpty) ? v : '';
  }

  /// Writes canonical + legacy keys so all profile loaders stay in sync.
  static Map<String, dynamic> nameUpdateFields(String name) {
    final trimmed = name.trim();
    return {
      'name': trimmed,
      'full_name': trimmed,
    };
  }

  static Map<String, dynamic> profilePhotoUpdateFields(String url) {
    final trimmed = url.trim();
    return {
      'profilePhoto': trimmed,
      'profilePic': trimmed,
      'photoURL': trimmed,
    };
  }
}
