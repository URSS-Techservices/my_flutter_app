import 'package:cloud_firestore/cloud_firestore.dart';

/// Tracks aspirant check-ins at wellness facilities and visit streaks.
class WellnessCheckInService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _checkInsRef(String aspirantId) {
    return _firestore.collection('users').doc(aspirantId).collection('wellnessCheckIns');
  }

  static String dateKey(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// One check-in per wellness per calendar day.
  Future<bool> checkInToday({
    required String aspirantId,
    required String wellnessUserId,
    required String wellnessName,
  }) async {
    if (aspirantId.isEmpty || wellnessUserId.isEmpty) return false;

    final today = dateKey(DateTime.now());
    final docId = '${wellnessUserId}_$today';
    final ref = _checkInsRef(aspirantId).doc(docId);
    final existing = await ref.get();
    if (existing.exists) return false;

    await ref.set({
      'wellnessUserId': wellnessUserId,
      'wellnessName': wellnessName,
      'dateKey': today,
      'checkedInAt': FieldValue.serverTimestamp(),
    });

    final streak = await _computeVisitStreak(aspirantId);
    final userRef = _firestore.collection('users').doc(aspirantId);
    final userSnap = await userRef.get();
    final stats = Map<String, dynamic>.from(
      (userSnap.data()?['fitnessStats'] as Map<String, dynamic>?) ?? {},
    );
    stats['visitStreak'] = streak;
    stats['lastCheckInAt'] = FieldValue.serverTimestamp();
    await userRef.set({'fitnessStats': stats}, SetOptions(merge: true));

    return true;
  }

  Future<bool> hasCheckedInToday({
    required String aspirantId,
    required String wellnessUserId,
  }) async {
    if (aspirantId.isEmpty || wellnessUserId.isEmpty) return false;
    final docId = '${wellnessUserId}_${dateKey(DateTime.now())}';
    final doc = await _checkInsRef(aspirantId).doc(docId).get();
    return doc.exists;
  }

  Stream<bool> hasCheckedInTodayStream({
    required String aspirantId,
    required String wellnessUserId,
  }) {
    if (aspirantId.isEmpty || wellnessUserId.isEmpty) return Stream.value(false);
    final docId = '${wellnessUserId}_${dateKey(DateTime.now())}';
    return _checkInsRef(aspirantId).doc(docId).snapshots().map((d) => d.exists);
  }

  Future<int> getVisitStreak(String aspirantId) async {
    if (aspirantId.isEmpty) return 0;
    return _computeVisitStreak(aspirantId);
  }

  Stream<int> visitStreakStream(String aspirantId) {
    if (aspirantId.isEmpty) return Stream.value(0);
    return _checkInsRef(aspirantId)
        .orderBy('checkedInAt', descending: true)
        .limit(90)
        .snapshots()
        .asyncMap((_) => _computeVisitStreak(aspirantId));
  }

  Future<int> _computeVisitStreak(String aspirantId) async {
    final snap = await _checkInsRef(aspirantId)
        .orderBy('checkedInAt', descending: true)
        .limit(120)
        .get();

    final days = <String>{};
    for (final doc in snap.docs) {
      final key = doc.data()['dateKey']?.toString();
      if (key != null && key.isNotEmpty) days.add(key);
    }
    if (days.isEmpty) return 0;

    var streak = 0;
    var cursor = DateTime.now();
    while (true) {
      final key = dateKey(cursor);
      if (days.contains(key)) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 1));
      } else if (streak == 0 && key == dateKey(DateTime.now())) {
        // Allow starting streak from yesterday if no check-in today yet.
        cursor = cursor.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }
}
