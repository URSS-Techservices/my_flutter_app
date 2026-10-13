import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:halo/profile_feature/domain/aspirant_fitness_stats.dart';
import 'package:halo/profile_feature/domain/aspirant_profile.dart';
import 'package:halo/profile_feature/domain/guru_profile.dart';
import 'package:halo/profile_feature/domain/profile_basics.dart';
import 'package:halo/profile_feature/domain/profile_counts.dart';
import 'package:halo/profile_feature/domain/wellness_booking.dart';
import 'package:halo/utils/search_utils.dart';

/// The only place the profile feature reads or writes `users/{id}`.
class ProfileRepository {
  ProfileRepository(this._firestore, this._storage);

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  DocumentReference<Map<String, dynamic>> _user(String id) =>
      _firestore.collection('users').doc(id);

  /// Fields every account type shows (header, stats, bio, links).
  ///
  /// [watchProfile] and [watchAspirant] listen to the same document;
  /// Firestore shares one connection between them.
  Stream<ProfileBasics?> watchProfile(String userId) {
    return _user(userId).snapshots().map((doc) {
      final data = doc.data();
      if (data == null) return null;
      return ProfileBasics.fromMap(doc.id, data);
    });
  }

  Stream<AspirantProfile?> watchAspirant(String userId) {
    return _user(userId).snapshots().map((doc) {
      final data = doc.data();
      if (data == null) return null;
      return AspirantProfile.fromMap(doc.id, data);
    });
  }

  /// Booking settings and up to 10 upcoming / completed sessions, for the
  /// guru booking screen. Falls back to lists stored on the user doc
  /// (older data) when the `sessions` subcollection is empty.
  Future<GuruBooking> loadGuruBooking(String guruId) async {
    final userRef = _user(guruId);
    final sessions = userRef.collection('sessions');
    final results = await Future.wait([
      userRef.get(),
      sessions.where('status', isEqualTo: 'upcoming').limit(10).get(),
      sessions.where('status', isEqualTo: 'completed').limit(10).get(),
    ]);
    final data = (results[0] as DocumentSnapshot<Map<String, dynamic>>).data() ??
        const <String, dynamic>{};
    final upcoming = results[1] as QuerySnapshot<Map<String, dynamic>>;
    final past = results[2] as QuerySnapshot<Map<String, dynamic>>;

    List<Map<String, dynamic>> sessionsOr(
      QuerySnapshot<Map<String, dynamic>> snap,
      Object? fallback,
    ) {
      if (snap.docs.isEmpty) {
        return fallback is List
            ? fallback.map((e) => Map<String, dynamic>.from(e as Map)).toList()
            : const [];
      }
      return snap.docs.map((doc) {
        final d = doc.data();
        final date = d['sessionDate'];
        return <String, dynamic>{
          'id': doc.id,
          'title': d['title'] ?? 'Session',
          'time': date is Timestamp
              ? _formatSessionTime(date.toDate())
              : (d['time'] ?? date ?? '').toString(),
          'studentName': d['studentName'] ?? '',
          'type': d['type'] ?? 'offline',
        };
      }).toList();
    }

    final settings = data['bookingSettings'];
    return GuruBooking(
      settings: settings is Map ? Map<String, dynamic>.from(settings) : const {},
      upcomingSessions: sessionsOr(upcoming, data['upcomingSessions']),
      pastSessions: sessionsOr(past, data['pastSessions']),
    );
  }

  /// Same format the old guru page used: d/m/yyyy h:mm.
  static String _formatSessionTime(DateTime d) =>
      '${d.day}/${d.month}/${d.year} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';

  /// My own booking requests to [wellnessId], newest first. Only my
  /// requests: other people's bookings are private (and the rules deny
  /// them). Two equality filters need no composite index; sorted here.
  Stream<List<WellnessBooking>> watchMyWellnessBookings({
    required String wellnessId,
    required String myId,
  }) {
    return _firestore
        .collection('booking_requests')
        .where('wellnessId', isEqualTo: wellnessId)
        .where('userId', isEqualTo: myId)
        .limit(20)
        .snapshots()
        .map((snap) {
      final list = [
        for (final d in snap.docs) WellnessBooking.fromMap(d.id, d.data()),
      ];
      final old = DateTime(2000);
      list.sort((a, b) => (b.createdAt ?? DateTime.now())
          .compareTo(a.createdAt ?? old));
      return list;
    });
  }

  /// Same fields the old wellness booking form wrote, so the owner's
  /// screen (Accept / Reject) shows new requests unchanged.
  Future<void> requestWellnessBooking({
    required String wellnessId,
    required String myId,
    required String service,
    required String preferredDate,
    required String preferredTime,
    required String note,
  }) {
    return _firestore.collection('booking_requests').add({
      'wellnessId': wellnessId,
      'userId': myId,
      'service': service,
      'preferredDate': preferredDate,
      'preferredTime': preferredTime,
      'note': note,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Visitors may only cancel their own pending request.
  Future<void> cancelWellnessBooking(String bookingId) {
    return _firestore.collection('booking_requests').doc(bookingId).update({
      'status': 'cancelled',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Counts the real posts / followers / following documents, so the numbers
  /// stay right even if a stored counter drifted. Each count is one cheap
  /// aggregate read, not a download of every document.
  Future<ProfileCounts> countAll(String userId) async {
    final results = await Future.wait([
      _firestore
          .collection('posts')
          .where('userId', isEqualTo: userId)
          .count()
          .get(),
      _user(userId).collection('followers').count().get(),
      _user(userId).collection('following').count().get(),
    ]);
    return ProfileCounts(
      posts: results[0].count ?? 0,
      followers: results[1].count ?? 0,
      following: results[2].count ?? 0,
    );
  }

  /// True if nobody except [myId] uses [username] (case-insensitive).
  Future<bool> isUsernameFree(String username, {required String myId}) async {
    final users = _firestore.collection('users');
    final results = await Future.wait([
      users
          .where('username_lower', isEqualTo: username.toLowerCase())
          .limit(2)
          .get(),
      // Older docs stored only the raw `username`.
      users.where('username', isEqualTo: username).limit(2).get(),
    ]);
    return results.every((snap) => snap.docs.every((d) => d.id == myId));
  }

  /// Uploads to Storage only; the URL is saved with the rest of the edit.
  Future<String> uploadPhoto({
    required String userId,
    required File file,
    required bool isCover,
  }) async {
    final name = '${isCover ? 'cover' : 'profile'}_${userId}_'
        '${DateTime.now().millisecondsSinceEpoch}';
    final snap =
        await _storage.ref().child('users').child(userId).child(name).putFile(file);
    return snap.ref.getDownloadURL();
  }

  /// Saves the whole Edit Profile form in one write. [fitnessStats] is only
  /// passed for aspirants.
  Future<void> saveProfile({
    required String userId,
    required String name,
    required String username,
    required String bio,
    required String location,
    required String website,
    required Map<String, String> socialLinks,
    AspirantFitnessStats? fitnessStats,
    String? profilePhotoUrl,
    String? coverPhotoUrl,
  }) {
    return _user(userId).update({
      'name': name,
      'full_name': name,
      'username': username,
      'username_lower': username.toLowerCase(),
      'searchTerms': buildSearchTerms(name: name, username: username),
      'bio': bio,
      'city': location,
      'website': website,
      'socialLinks': socialLinks,
      if (fitnessStats != null) ...fitnessStats.toUpdate(),
      if (profilePhotoUrl != null) 'profilePhoto': profilePhotoUrl,
      if (coverPhotoUrl != null) 'coverPhoto': coverPhotoUrl,
    });
  }
}
