import 'package:cloud_firestore/cloud_firestore.dart';

/// Unified guru offering types stored in `users/{guruId}/programs/{programId}`.
enum GuruProgramType {
  program,
  product,
  classBatch,
}

extension GuruProgramTypeX on GuruProgramType {
  String get firestoreValue {
    switch (this) {
      case GuruProgramType.program:
        return 'program';
      case GuruProgramType.product:
        return 'product';
      case GuruProgramType.classBatch:
        return 'class';
    }
  }

  static GuruProgramType fromRaw(String? raw) {
    switch (raw) {
      case 'product':
        return GuruProgramType.product;
      case 'class':
        return GuruProgramType.classBatch;
      default:
        return GuruProgramType.program;
    }
  }
}

class GuruProgramsLoadResult {
  final List<Map<String, dynamic>> all;

  const GuruProgramsLoadResult({required this.all});

  List<Map<String, dynamic>> get programs =>
      all.where((p) => p['type'] == GuruProgramType.program.firestoreValue).toList();

  List<Map<String, dynamic>> get products =>
      all.where((p) => p['type'] == GuruProgramType.product.firestoreValue).toList();

  List<Map<String, dynamic>> get classes =>
      all.where((p) => p['type'] == GuruProgramType.classBatch.firestoreValue).toList();
}

/// Loads, migrates, and saves guru programs/products/classes in one subcollection.
class GuruProgramsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const collectionName = 'programs';

  CollectionReference<Map<String, dynamic>> _programsRef(String guruId) {
    return _firestore.collection('users').doc(guruId).collection(collectionName);
  }

  Future<GuruProgramsLoadResult> load({
    required String guruId,
    Map<String, dynamic>? userData,
  }) async {
    if (guruId.isEmpty) return const GuruProgramsLoadResult(all: []);

    final snap = await _programsRef(guruId).orderBy('sortOrder').get();

    final active = snap.docs
        .where((d) => d.data()['isActive'] != false)
        .map((d) => _fromDoc(d.id, d.data()))
        .toList();

    if (active.isNotEmpty) {
      return GuruProgramsLoadResult(all: active);
    }

    final migrated = await _migrateLegacy(guruId: guruId, userData: userData ?? {});
    return GuruProgramsLoadResult(all: migrated);
  }

  Stream<GuruProgramsLoadResult> stream(String guruId) {
    if (guruId.isEmpty) return Stream.value(const GuruProgramsLoadResult(all: []));
    return _programsRef(guruId).orderBy('sortOrder').snapshots().map((snap) {
      final active = snap.docs
          .where((d) => d.data()['isActive'] != false)
          .map((d) => _fromDoc(d.id, d.data()))
          .toList();
      return GuruProgramsLoadResult(all: active);
    });
  }

  Future<String> upsert({
    required String guruId,
    String? programId,
    required GuruProgramType type,
    required String name,
    String duration = '',
    String schedule = '',
    int price = 0,
    String description = '',
    int enrolled = 0,
    int capacity = 0,
    String? imageUrl,
    String? tag,
    bool isActive = true,
    int? sortOrder,
  }) async {
    final ref = programId != null && programId.isNotEmpty
        ? _programsRef(guruId).doc(programId)
        : _programsRef(guruId).doc();

    final data = <String, dynamic>{
      'name': name.trim(),
      'type': type.firestoreValue,
      'duration': duration.trim(),
      'schedule': schedule.trim(),
      'price': price,
      'description': description.trim(),
      'enrolled': enrolled,
      'capacity': capacity,
      'imageUrl': imageUrl,
      'tag': tag,
      'isActive': isActive,
      'sortOrder': sortOrder ?? DateTime.now().millisecondsSinceEpoch,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (programId == null || programId.isEmpty) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }

    await ref.set(data, SetOptions(merge: true));
    return ref.id;
  }

  Future<void> delete({required String guruId, required String programId}) async {
    await _programsRef(guruId).doc(programId).set({
      'isActive': false,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Map<String, dynamic> _fromDoc(String id, Map<String, dynamic> data) {
    return {
      'id': id,
      'name': data['name'] ?? '',
      'type': data['type'] ?? GuruProgramType.program.firestoreValue,
      'duration': data['duration'] ?? '',
      'schedule': data['schedule'] ?? '',
      'price': data['price'] ?? 0,
      'description': data['description'] ?? '',
      'enrolled': data['enrolled'] ?? 0,
      'capacity': data['capacity'] ?? 0,
      'imageUrl': data['imageUrl'],
      'tag': data['tag'],
      'isActive': data['isActive'] ?? true,
      'sortOrder': data['sortOrder'] ?? 0,
    };
  }

  static Map<String, dynamic> asClassView(Map<String, dynamic> program) {
    return {
      'id': program['id'],
      'name': program['name'],
      'schedule': program['schedule'] ?? program['duration'] ?? '',
      'enrolled': program['enrolled'] ?? 0,
      'capacity': program['capacity'] ?? 0,
      'price': program['price'] ?? 0,
      'imageUrl': program['imageUrl'],
    };
  }

  Future<List<Map<String, dynamic>>> _migrateLegacy({
    required String guruId,
    required Map<String, dynamic> userData,
  }) async {
    final batch = _firestore.batch();
    final entries = <Map<String, dynamic>>[];
    var order = 0;

    void addEntry(GuruProgramType type, Map<String, dynamic> raw, {String? docId}) {
      final id = docId ?? _programsRef(guruId).doc().id;
      final data = {
        'name': raw['name'] ?? raw['title'] ?? 'Offering',
        'type': type.firestoreValue,
        'duration': raw['duration']?.toString() ?? '',
        'schedule': raw['schedule']?.toString() ?? '',
        'price': raw['price'] is num ? raw['price'] : int.tryParse('${raw['price']}') ?? 0,
        'description': raw['description']?.toString() ?? '',
        'enrolled': raw['enrolled'] ?? 0,
        'capacity': raw['capacity'] ?? 0,
        'imageUrl': raw['imageUrl'],
        'tag': raw['tag'],
        'isActive': raw['isActive'] ?? true,
        'sortOrder': order++,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'migratedFrom': type.firestoreValue,
      };
      batch.set(_programsRef(guruId).doc(id), data);
      entries.add(_fromDoc(id, data));
    }

    try {
      final classesSnap = await _firestore
          .collection('users')
          .doc(guruId)
          .collection('classes')
          .limit(50)
          .get();
      for (final doc in classesSnap.docs) {
        addEntry(GuruProgramType.classBatch, doc.data(), docId: doc.id);
      }
    } catch (_) {}

    final legacyClasses = userData['classes'];
    if (legacyClasses is List) {
      for (final item in legacyClasses) {
        if (item is Map) {
          addEntry(GuruProgramType.classBatch, Map<String, dynamic>.from(item));
        }
      }
    }

    final products = userData['popularProducts'];
    if (products is List) {
      for (final item in products) {
        if (item is Map) {
          addEntry(GuruProgramType.product, Map<String, dynamic>.from(item));
        }
      }
    }

    final programs = userData['trainingPrograms'];
    if (programs is List) {
      for (final item in programs) {
        if (item is Map) {
          addEntry(GuruProgramType.program, Map<String, dynamic>.from(item));
        }
      }
    }

    if (entries.isEmpty) return [];

    await batch.commit();
    return entries;
  }
}
