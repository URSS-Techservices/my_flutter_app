/// Wellness-only fields of `users/{id}` (gym, spa, studio …).
class WellnessProfile {
  /// Guru accounts the owner features on their page, in the owner's order.
  final List<String> featuredGuruIds;

  /// Facilities and services: chosen at signup (`facilities_services`) plus
  /// any added later on the old page (`services`), without duplicates.
  final List<String> services;

  /// Free text from signup, e.g. "6 AM – 10 PM".
  final String workingHours;

  /// Day → hours, from the old page ("Mon" → "6 AM – 9 PM").
  final Map<String, String> availability;

  const WellnessProfile({
    required this.featuredGuruIds,
    required this.services,
    required this.workingHours,
    required this.availability,
  });

  /// Most gurus a wellness page can feature.
  static const maxFeaturedGurus = 10;

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  factory WellnessProfile.fromMap(Map<String, dynamic> map) {
    List<String> list(Object? v) => v is List
        ? [
            for (final e in v)
              if (e != null && e.toString().trim().isNotEmpty)
                e.toString().trim(),
          ]
        : const [];

    final seen = <String>{};
    final services = [
      for (final s in [
        ...list(map['facilities_services']),
        ...list(map['services']),
      ])
        if (seen.add(s.toLowerCase())) s,
    ];

    final rawDays = map['availability'];
    final availability = <String, String>{
      if (rawDays is Map)
        for (final day in _days)
          if ((rawDays[day]?.toString().trim() ?? '').isNotEmpty)
            day: rawDays[day].toString().trim(),
    };

    final hours = map['working_hours'];
    return WellnessProfile(
      featuredGuruIds: list(map['featuredGuruIds']),
      services: services,
      workingHours: hours is String ? hours.trim() : '',
      availability: availability,
    );
  }

  bool get hasServicesInfo =>
      services.isNotEmpty || workingHours.isNotEmpty || availability.isNotEmpty;
}
