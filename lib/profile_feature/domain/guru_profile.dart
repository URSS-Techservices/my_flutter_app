/// What the guru booking screen needs: settings from the user doc plus the
/// guru's upcoming and completed sessions.
class GuruBooking {
  /// Prices, duration, online/offline.
  final Map<String, dynamic> settings;
  final List<Map<String, dynamic>> upcomingSessions;
  final List<Map<String, dynamic>> pastSessions;

  const GuruBooking({
    required this.settings,
    required this.upcomingSessions,
    required this.pastSessions,
  });
}
