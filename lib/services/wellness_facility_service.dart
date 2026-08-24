import 'package:cloud_firestore/cloud_firestore.dart';

/// Staff and fitness events for wellness facility profiles.
class WellnessFacilityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _staffRef(String wellnessId) {
    return _firestore.collection('users').doc(wellnessId).collection('staff');
  }

  CollectionReference<Map<String, dynamic>> _eventsRef(String wellnessId) {
    return _firestore.collection('users').doc(wellnessId).collection('events');
  }

  Future<List<Map<String, dynamic>>> loadStaff({
    required String wellnessId,
    Map<String, dynamic>? userData,
  }) async {
    if (wellnessId.isEmpty) return [];

    final snap = await _staffRef(wellnessId).orderBy('sortOrder').get();
    final active = snap.docs
        .where((d) => d.data()['isActive'] != false)
        .map((d) => _staffFromDoc(d.id, d.data()))
        .toList();
    if (active.isNotEmpty) return active;

    return _migrateLegacyStaff(wellnessId: wellnessId, userData: userData ?? {});
  }

  Future<List<Map<String, dynamic>>> loadEvents({
    required String wellnessId,
    Map<String, dynamic>? userData,
  }) async {
    if (wellnessId.isEmpty) return [];

    final snap = await _eventsRef(wellnessId).orderBy('sortOrder').get();
    final active = snap.docs
        .where((d) => d.data()['isActive'] != false)
        .map((d) => _eventFromDoc(d.id, d.data()))
        .toList();
    if (active.isNotEmpty) return active;

    return _migrateLegacyEvents(wellnessId: wellnessId, userData: userData ?? {});
  }

  Stream<List<Map<String, dynamic>>> staffStream(String wellnessId) {
    if (wellnessId.isEmpty) return Stream.value(const []);
    return _staffRef(wellnessId).orderBy('sortOrder').snapshots().map((snap) {
      return snap.docs
          .where((d) => d.data()['isActive'] != false)
          .map((d) => _staffFromDoc(d.id, d.data()))
          .toList();
    });
  }

  Stream<List<Map<String, dynamic>>> eventsStream(String wellnessId) {
    if (wellnessId.isEmpty) return Stream.value(const []);
    return _eventsRef(wellnessId).orderBy('sortOrder').snapshots().map((snap) {
      return snap.docs
          .where((d) => d.data()['isActive'] != false)
          .map((d) => _eventFromDoc(d.id, d.data()))
          .toList();
    });
  }

  Future<String> upsertStaff({
    required String wellnessId,
    String? staffId,
    required String name,
    String role = '',
    String? photoUrl,
    String bio = '',
    int? sortOrder,
  }) async {
    final ref = staffId != null && staffId.isNotEmpty
        ? _staffRef(wellnessId).doc(staffId)
        : _staffRef(wellnessId).doc();

    final data = <String, dynamic>{
      'name': name.trim(),
      'role': role.trim(),
      'photoUrl': photoUrl,
      'bio': bio.trim(),
      'isActive': true,
      'sortOrder': sortOrder ?? DateTime.now().millisecondsSinceEpoch,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (staffId == null || staffId.isEmpty) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }

    await ref.set(data, SetOptions(merge: true));
    return ref.id;
  }

  Future<void> deleteStaff({required String wellnessId, required String staffId}) async {
    await _staffRef(wellnessId).doc(staffId).set({
      'isActive': false,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<String> upsertEvent({
    required String wellnessId,
    String? eventId,
    required String title,
    String date = '',
    String time = '',
    String place = '',
    String? imageUrl,
    String description = '',
    int? sortOrder,
  }) async {
    final ref = eventId != null && eventId.isNotEmpty
        ? _eventsRef(wellnessId).doc(eventId)
        : _eventsRef(wellnessId).doc();

    final data = <String, dynamic>{
      'title': title.trim(),
      'name': title.trim(),
      'date': date.trim(),
      'time': time.trim(),
      'place': place.trim(),
      'imageUrl': imageUrl,
      'description': description.trim(),
      'isActive': true,
      'sortOrder': sortOrder ?? DateTime.now().millisecondsSinceEpoch,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (eventId == null || eventId.isEmpty) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }

    await ref.set(data, SetOptions(merge: true));
    return ref.id;
  }

  Future<void> deleteEvent({required String wellnessId, required String eventId}) async {
    await _eventsRef(wellnessId).doc(eventId).set({
      'isActive': false,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static String eventTitle(Map<String, dynamic> event) {
    final title = event['title']?.toString().trim();
    if (title != null && title.isNotEmpty) return title;
    return event['name']?.toString().trim() ?? 'Event';
  }

  static String eventWhen(Map<String, dynamic> event) {
    final date = event['date']?.toString().trim() ?? '';
    final time = event['time']?.toString().trim() ?? '';
    if (date.isEmpty && time.isEmpty) return '';
    if (time.isEmpty) return date;
    if (date.isEmpty) return time;
    return '$date · $time';
  }

  Map<String, dynamic> _staffFromDoc(String id, Map<String, dynamic> data) {
    return {
      'id': id,
      'name': data['name'] ?? '',
      'role': data['role'] ?? data['title'] ?? '',
      'photoUrl': data['photoUrl'],
      'bio': data['bio'] ?? '',
      'sortOrder': data['sortOrder'] ?? 0,
    };
  }

  Map<String, dynamic> _eventFromDoc(String id, Map<String, dynamic> data) {
    return {
      'id': id,
      ...data,
      'title': eventTitle(data),
    };
  }

  Future<List<Map<String, dynamic>>> _migrateLegacyStaff({
    required String wellnessId,
    required Map<String, dynamic> userData,
  }) async {
    final legacy = userData['staff'] ?? userData['featuredStaff'];
    if (legacy is! List || legacy.isEmpty) return [];

    final batch = _firestore.batch();
    final entries = <Map<String, dynamic>>[];
    var order = 0;

    for (final item in legacy) {
      if (item is! Map) continue;
      final raw = Map<String, dynamic>.from(item);
      final id = _staffRef(wellnessId).doc().id;
      final data = {
        'name': raw['name'] ?? 'Staff',
        'role': raw['role'] ?? raw['title'] ?? '',
        'photoUrl': raw['photoUrl'],
        'bio': raw['bio'] ?? '',
        'isActive': true,
        'sortOrder': order++,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'migratedFrom': 'userDoc',
      };
      batch.set(_staffRef(wellnessId).doc(id), data);
      entries.add(_staffFromDoc(id, data));
    }

    await batch.commit();
    return entries;
  }

  Future<List<Map<String, dynamic>>> _migrateLegacyEvents({
    required String wellnessId,
    required Map<String, dynamic> userData,
  }) async {
    final legacy = userData['fitnessEvents'] ?? userData['events'];
    if (legacy is! List || legacy.isEmpty) return [];

    final batch = _firestore.batch();
    final entries = <Map<String, dynamic>>[];
    var order = 0;

    for (final item in legacy) {
      if (item is! Map) continue;
      final raw = Map<String, dynamic>.from(item);
      final id = _eventsRef(wellnessId).doc().id;
      final title = raw['title']?.toString() ?? raw['name']?.toString() ?? 'Event';
      final data = {
        'title': title,
        'name': title,
        'date': raw['date']?.toString() ?? '',
        'time': raw['time']?.toString() ?? '',
        'place': raw['place']?.toString() ?? '',
        'imageUrl': raw['imageUrl'],
        'description': raw['description']?.toString() ?? '',
        'isActive': true,
        'sortOrder': order++,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'migratedFrom': 'userDoc',
      };
      batch.set(_eventsRef(wellnessId).doc(id), data);
      entries.add(_eventFromDoc(id, data));
    }

    await batch.commit();
    return entries;
  }
}
