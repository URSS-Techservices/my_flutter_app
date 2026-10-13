import 'package:cloud_firestore/cloud_firestore.dart';

/// One booking request from a visitor to a wellness centre
/// (`booking_requests/{id}`). The wellness owner accepts or rejects it.
class WellnessBooking {
  final String id;
  final String service;
  final String preferredDate;
  final String preferredTime;
  final String note;

  /// pending · accepted · rejected · cancelled
  final String status;
  final DateTime? createdAt;

  const WellnessBooking({
    required this.id,
    required this.service,
    required this.preferredDate,
    required this.preferredTime,
    required this.note,
    required this.status,
    required this.createdAt,
  });

  factory WellnessBooking.fromMap(String id, Map<String, dynamic> map) {
    String text(Object? v) => v is String ? v.trim() : '';
    final created = map['createdAt'];
    return WellnessBooking(
      id: id,
      service: text(map['service']),
      preferredDate: text(map['preferredDate']),
      preferredTime: text(map['preferredTime']),
      note: text(map['note']),
      status: text(map['status']).isEmpty ? 'pending' : text(map['status']),
      createdAt: created is Timestamp ? created.toDate() : null,
    );
  }
}
