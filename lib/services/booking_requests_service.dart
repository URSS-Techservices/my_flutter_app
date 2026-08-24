import 'package:cloud_firestore/cloud_firestore.dart';

enum BookingProviderKind { guru, wellness }

class BookingProviderInfo {
  final String? userId;
  final String name;
  final String kindLabel;

  const BookingProviderInfo({
    this.userId,
    required this.name,
    this.kindLabel = '',
  });
}

/// Reads and updates `booking_requests` for gurus, wellness owners, and requesters.
class BookingRequestsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const statusPending = 'pending';
  static const statusAccepted = 'accepted';
  static const statusDeclined = 'declined';
  static const statusCancelled = 'cancelled';

  String _providerField(BookingProviderKind kind) {
    return kind == BookingProviderKind.guru ? 'guruId' : 'wellnessId';
  }

  Stream<List<Map<String, dynamic>>> providerRequestsStream({
    required String providerId,
    required BookingProviderKind kind,
  }) {
    if (providerId.isEmpty) return Stream.value(const []);

    return _firestore
        .collection('booking_requests')
        .where(_providerField(kind), isEqualTo: providerId)
        .snapshots()
        .map((snap) => _sortNewestFirst(
              snap.docs.map((d) => _fromDoc(d.id, d.data())).toList(),
            ));
  }

  Stream<List<Map<String, dynamic>>> requesterRequestsStream(String userId) {
    if (userId.isEmpty) return Stream.value(const []);

    return _firestore
        .collection('booking_requests')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snap) => _sortNewestFirst(
              snap.docs.map((d) => _fromDoc(d.id, d.data())).toList(),
            ));
  }

  Future<void> updateStatus({
    required String requestId,
    required String status,
  }) async {
    await _firestore.collection('booking_requests').doc(requestId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> accept(String requestId) =>
      updateStatus(requestId: requestId, status: statusAccepted);

  Future<void> decline(String requestId) =>
      updateStatus(requestId: requestId, status: statusDeclined);

  Future<void> cancel(String requestId) =>
      updateStatus(requestId: requestId, status: statusCancelled);

  Future<String> fetchUserDisplayName(String userId) async {
    if (userId.isEmpty) return 'User';
    final snap = await _firestore.collection('users').doc(userId).get();
    final data = snap.data();
    if (data == null) return 'User';
    return (data['name'] ?? data['full_name'] ?? data['username'] ?? 'User').toString();
  }

  /// Resolves guru or wellness provider from a booking request doc.
  Future<BookingProviderInfo> resolveProvider(Map<String, dynamic> request) async {
    final guruId = request['guruId']?.toString() ?? '';
    final wellnessId = request['wellnessId']?.toString() ?? '';
    final providerId = guruId.isNotEmpty ? guruId : wellnessId;
    if (providerId.isEmpty) {
      return const BookingProviderInfo(name: 'Provider');
    }

    final snap = await _firestore.collection('users').doc(providerId).get();
    final data = snap.data() ?? {};
    final name = (data['name'] ??
            data['full_name'] ??
            data['businessName'] ??
            data['username'] ??
            'Provider')
        .toString();
    final kind = guruId.isNotEmpty ? BookingProviderKind.guru : BookingProviderKind.wellness;
    final kindLabel = kind == BookingProviderKind.guru ? 'Coach' : 'Wellness';

    return BookingProviderInfo(userId: providerId, name: name, kindLabel: kindLabel);
  }

  static String displayWhen(Map<String, dynamic> request) {
    final slotDate = request['slotDate']?.toString();
    final slotTime = request['slotTime']?.toString();
    if (slotDate != null && slotDate.isNotEmpty) {
      if (slotTime != null && slotTime.isNotEmpty) return '$slotDate · $slotTime';
      return slotDate;
    }
    final date = request['preferredDate']?.toString() ?? '';
    final time = request['preferredTime']?.toString() ?? '';
    if (date.isEmpty && time.isEmpty) return 'Time TBD';
    if (time.isEmpty) return date;
    if (date.isEmpty) return time;
    return '$date · $time';
  }

  static String displayService(Map<String, dynamic> request) {
    return request['service']?.toString().trim().isNotEmpty == true
        ? request['service'].toString()
        : 'Session';
  }

  static bool isPending(Map<String, dynamic> request) =>
      (request['status']?.toString() ?? statusPending) == statusPending;

  static bool isAccepted(Map<String, dynamic> request) =>
      request['status']?.toString() == statusAccepted;

  Map<String, dynamic> _fromDoc(String id, Map<String, dynamic> data) {
    return {'id': id, ...data};
  }

  List<Map<String, dynamic>> _sortNewestFirst(List<Map<String, dynamic>> items) {
    items.sort((a, b) {
      final aTs = a['createdAt'];
      final bTs = b['createdAt'];
      if (aTs is Timestamp && bTs is Timestamp) return bTs.compareTo(aTs);
      return 0;
    });
    return items;
  }
}
