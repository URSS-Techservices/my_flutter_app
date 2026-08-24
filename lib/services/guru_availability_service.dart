import 'package:cloud_firestore/cloud_firestore.dart';

/// A bookable guru time slot on a specific calendar day.
class GuruAvailableSlot {
  final DateTime date;
  final String time24; // HH:mm

  const GuruAvailableSlot({required this.date, required this.time24});

  String get dateKey {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String get slotId => '${dateKey}_$time24';

  String get displayTime => GuruAvailabilityService.formatTime12(time24);

  String get displayDate {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final w = weekdays[date.weekday - 1];
    return '$w ${date.month}/${date.day}';
  }
}

/// Weekly recurring slots + booked-slot checks for guru booking.
class GuruAvailabilityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const fieldName = 'weeklyAvailability';

  static const dayLabels = {
    '1': 'Monday',
    '2': 'Tuesday',
    '3': 'Wednesday',
    '4': 'Thursday',
    '5': 'Friday',
    '6': 'Saturday',
    '7': 'Sunday',
  };

  Stream<Map<String, List<String>>> weeklySlotsStream(String guruId) {
    if (guruId.isEmpty) return Stream.value({});
    return _firestore.collection('users').doc(guruId).snapshots().map((snap) {
      return parseWeeklySlots(snap.data()?[fieldName]);
    });
  }

  static Map<String, List<String>> parseWeeklySlots(dynamic raw) {
    if (raw is! Map) return {};
    final out = <String, List<String>>{};
    for (final entry in raw.entries) {
      final key = entry.key.toString();
      final list = entry.value;
      if (list is List) {
        out[key] = list.map((e) => e.toString()).where((t) => t.isNotEmpty).toList()..sort();
      }
    }
    return out;
  }

  Future<void> saveWeeklySlots({
    required String guruId,
    required Map<String, List<String>> slots,
  }) async {
    if (guruId.isEmpty) return;
    final normalized = <String, List<String>>{};
    for (final entry in slots.entries) {
      final times = entry.value.map((t) => normalizeTime24(t)).where((t) => t.isNotEmpty).toSet().toList()..sort();
      if (times.isNotEmpty) normalized[entry.key] = times;
    }
    await _firestore.collection('users').doc(guruId).set({
      fieldName: normalized,
      'bookingSettings.hasWeeklySlots': normalized.isNotEmpty,
    }, SetOptions(merge: true));
  }

  Future<List<GuruAvailableSlot>> getAvailableSlots({
    required String guruId,
    int daysAhead = 14,
  }) async {
    if (guruId.isEmpty) return [];

    final userSnap = await _firestore.collection('users').doc(guruId).get();
    final weekly = parseWeeklySlots(userSnap.data()?[fieldName]);
    if (weekly.isEmpty) return [];

    final booked = await _loadBookedSlotIds(guruId);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final slots = <GuruAvailableSlot>[];

    for (var i = 0; i < daysAhead; i++) {
      final date = today.add(Duration(days: i));
      final weekdayKey = date.weekday.toString();
      final times = weekly[weekdayKey] ?? const [];
      for (final time in times) {
        final slot = GuruAvailableSlot(date: date, time24: time);
        if (_isSlotInPast(slot, now)) continue;
        if (booked.contains(slot.slotId)) continue;
        slots.add(slot);
      }
    }
    return slots;
  }

  Future<Set<String>> _loadBookedSlotIds(String guruId) async {
    final snap = await _firestore
        .collection('booking_requests')
        .where('guruId', isEqualTo: guruId)
        .where('status', whereIn: ['pending', 'accepted'])
        .limit(100)
        .get();

    final ids = <String>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      final slotId = data['slotId']?.toString();
      if (slotId != null && slotId.isNotEmpty) {
        ids.add(slotId);
        continue;
      }
      final date = data['slotDate']?.toString() ?? data['preferredDate']?.toString() ?? '';
      final time = normalizeTime24(data['slotTime']?.toString() ?? data['preferredTime']?.toString() ?? '');
      if (date.isNotEmpty && time.isNotEmpty) {
        ids.add('${date}_$time');
      }
    }
    return ids;
  }

  bool _isSlotInPast(GuruAvailableSlot slot, DateTime now) {
    final parts = slot.time24.split(':');
    if (parts.length < 2) return false;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final slotDt = DateTime(slot.date.year, slot.date.month, slot.date.day, h, m);
    return slotDt.isBefore(now);
  }

  static String normalizeTime24(String raw) {
    final trimmed = raw.trim().toLowerCase();
    if (trimmed.isEmpty) return '';

    final match24 = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(trimmed);
    if (match24 != null) {
      final h = int.parse(match24.group(1)!).clamp(0, 23);
      final m = int.parse(match24.group(2)!).clamp(0, 59);
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    }

    final match12 = RegExp(r'^(\d{1,2})(?::(\d{2}))?\s*(am|pm)$').firstMatch(trimmed);
    if (match12 != null) {
      var h = int.parse(match12.group(1)!);
      final m = int.tryParse(match12.group(2) ?? '0') ?? 0;
      final mer = match12.group(3)!;
      if (h == 12) {
        h = mer == 'am' ? 0 : 12;
      } else if (mer == 'pm') {
        h += 12;
      }
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    }
    return trimmed;
  }

  static String formatTime12(String time24) {
    final parts = time24.split(':');
    if (parts.length < 2) return time24;
    var h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final mer = h >= 12 ? 'PM' : 'AM';
    h = h % 12;
    if (h == 0) h = 12;
    if (m == 0) return '$h:00 $mer';
    return '$h:${m.toString().padLeft(2, '0')} $mer';
  }
}
