/// Parses wellness facility hours and computes open/closed status.
class WellnessFacilityHours {
  final Map<String, String> availability;
  final Map<String, dynamic>? facilityHours;

  const WellnessFacilityHours({
    required this.availability,
    this.facilityHours,
  });

  factory WellnessFacilityHours.fromFirestore({
    Map<String, dynamic>? availabilityRaw,
    Map<String, dynamic>? facilityHoursRaw,
  }) {
    final availability = <String, String>{};
    if (availabilityRaw != null) {
      for (final entry in availabilityRaw.entries) {
        final v = entry.value?.toString().trim() ?? '';
        if (v.isNotEmpty) availability[entry.key.toString()] = v;
      }
    }
    return WellnessFacilityHours(
      availability: availability,
      facilityHours: facilityHoursRaw,
    );
  }

  FacilityOpenStatus statusAt([DateTime? now]) {
    now ??= DateTime.now();
    final scheduleKey = _scheduleKeyForWeekday(now.weekday);
    final rangeText = _rangeTextForKey(scheduleKey);
    if (rangeText == null || rangeText.isEmpty) {
      return FacilityOpenStatus(
        isOpen: false,
        label: 'Hours not set',
        subtitle: null,
        scheduleKey: scheduleKey,
        hoursLabel: null,
      );
    }

    final range = _parseRange(rangeText);
    if (range == null) {
      return FacilityOpenStatus(
        isOpen: false,
        label: 'See hours below',
        subtitle: rangeText,
        scheduleKey: scheduleKey,
        hoursLabel: '$scheduleKey: $rangeText',
      );
    }

    final minutesNow = now.hour * 60 + now.minute;
    final isOpen = minutesNow >= range.openMinutes && minutesNow < range.closeMinutes;
    final closesAt = _formatMinutes(range.closeMinutes);
    final opensAt = _formatMinutes(range.openMinutes);

    return FacilityOpenStatus(
      isOpen: isOpen,
      label: isOpen ? 'Open Now' : 'Closed',
      subtitle: isOpen ? 'Closes $closesAt' : 'Opens $opensAt',
      scheduleKey: scheduleKey,
      hoursLabel: '$scheduleKey: $rangeText',
    );
  }

  List<MapEntry<String, String>> displayEntries() {
    if (availability.isNotEmpty) return availability.entries.toList();
    if (facilityHours != null) {
      final open = facilityHours!['openTime']?.toString() ?? '';
      final close = facilityHours!['closeTime']?.toString() ?? '';
      final days = facilityHours!['days']?.toString() ?? 'Hours';
      if (open.isNotEmpty && close.isNotEmpty) {
        return [MapEntry(days, '$open - $close')];
      }
    }
    return const [];
  }

  String? _rangeTextForKey(String scheduleKey) {
    if (availability.containsKey(scheduleKey)) {
      return availability[scheduleKey];
    }
    if (scheduleKey == 'Sun') {
      return availability['Sunday'] ?? availability['sun'];
    }
    final weekday = availability['Mon-Sat'] ??
        availability['Mon–Sat'] ??
        availability['Weekdays'] ??
        availability['Monday-Saturday'];
    if (weekday != null) return weekday;

    if (facilityHours != null) {
      final open = facilityHours!['openTime']?.toString().trim() ?? '';
      final close = facilityHours!['closeTime']?.toString().trim() ?? '';
      if (open.isNotEmpty && close.isNotEmpty) return '$open - $close';
    }
    return null;
  }

  static String _scheduleKeyForWeekday(int weekday) {
    // DateTime.weekday: 1=Mon ... 7=Sun
    return weekday == DateTime.sunday ? 'Sun' : 'Mon-Sat';
  }

  static _TimeRange? _parseRange(String raw) {
    final normalized = raw.trim().toLowerCase().replaceAll('–', '-');
    final match = RegExp(
      r'(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\s*-\s*(\d{1,2})(?::(\d{2}))?\s*(am|pm)?',
    ).firstMatch(normalized);
    if (match == null) return null;

    final open = _toMinutes(
      hour: int.parse(match.group(1)!),
      minute: int.tryParse(match.group(2) ?? '0') ?? 0,
      meridiem: match.group(3),
      isClose: false,
      pairedMeridiem: match.group(6),
    );
    final close = _toMinutes(
      hour: int.parse(match.group(4)!),
      minute: int.tryParse(match.group(5) ?? '0') ?? 0,
      meridiem: match.group(6),
      isClose: true,
      pairedMeridiem: match.group(3),
    );
    if (open == null || close == null) return null;
    return _TimeRange(openMinutes: open, closeMinutes: close);
  }

  static int? _toMinutes({
    required int hour,
    required int minute,
    required String? meridiem,
    required bool isClose,
    required String? pairedMeridiem,
  }) {
    var h = hour;
    final m = minute.clamp(0, 59);
    var mer = meridiem?.toLowerCase();

    if (mer == null || mer.isEmpty) {
      // 24h style when both sides omit am/pm
      if (h >= 24) return null;
      return h * 60 + m;
    }

    if (h == 12) {
      h = mer == 'am' ? 0 : 12;
    } else if (mer == 'pm') {
      h += 12;
    }

    // If open is pm and close am missing on close side, infer close pm when close < open hour in 12h
    if (!isClose && pairedMeridiem == null && h < 12 && mer == 'am') {
      // keep as am
    }

    return h * 60 + m;
  }

  static String _formatMinutes(int minutes) {
    final h24 = minutes ~/ 60;
    final m = minutes % 60;
    final mer = h24 >= 12 ? 'PM' : 'AM';
    var h12 = h24 % 12;
    if (h12 == 0) h12 = 12;
    if (m == 0) return '$h12:00 $mer';
    return '$h12:${m.toString().padLeft(2, '0')} $mer';
  }
}

class FacilityOpenStatus {
  final bool isOpen;
  final String label;
  final String? subtitle;
  final String scheduleKey;
  final String? hoursLabel;

  const FacilityOpenStatus({
    required this.isOpen,
    required this.label,
    required this.subtitle,
    required this.scheduleKey,
    required this.hoursLabel,
  });

  bool get hasKnownHours => hoursLabel != null || subtitle != null;
}

class _TimeRange {
  final int openMinutes;
  final int closeMinutes;

  const _TimeRange({required this.openMinutes, required this.closeMinutes});
}
