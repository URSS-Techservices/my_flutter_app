/// Instagram-style activity status for a profile.
///
/// - "Active now" (green dot) while the app is open on their phone.
/// - "Active 5m ago", "Active 3h ago", "Active yesterday" after that.
/// - Nothing after 2 days, or when either person turned activity status off.
class ActivityStatus {
  final bool activeNow;

  /// Text under the name, or null to show nothing.
  final String? label;

  const ActivityStatus._(this.activeNow, this.label);

  static const hidden = ActivityStatus._(false, null);

  /// The app refreshes `lastSeen` every 2 minutes while open, so anything
  /// older than this means the app was closed or crashed.
  static const freshFor = Duration(minutes: 5);

  factory ActivityStatus.from({
    required bool isOnline,
    required DateTime? lastSeen,
    required DateTime now,
  }) {
    if (lastSeen == null) return hidden;
    final age = now.difference(lastSeen);
    if (isOnline && age < freshFor) {
      return const ActivityStatus._(true, 'Active now');
    }
    if (age < const Duration(hours: 1)) {
      final minutes = age.inMinutes < 1 ? 1 : age.inMinutes;
      return ActivityStatus._(false, 'Active ${minutes}m ago');
    }
    if (age < const Duration(hours: 24)) {
      return ActivityStatus._(false, 'Active ${age.inHours}h ago');
    }
    if (age < const Duration(hours: 48)) {
      return const ActivityStatus._(false, 'Active yesterday');
    }
    return hidden;
  }
}
