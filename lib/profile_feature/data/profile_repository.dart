import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:halo/profile_feature/domain/aspirant_fitness_stats.dart';
import 'package:halo/profile_feature/domain/aspirant_profile.dart';
import 'package:halo/profile_feature/domain/profile_counts.dart';
import 'package:halo/utils/search_utils.dart';

/// The only place the profile feature reads or writes `users/{id}`.
class ProfileRepository {
  ProfileRepository(this._firestore, this._storage);

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  DocumentReference<Map<String, dynamic>> _user(String id) =>
      _firestore.collection('users').doc(id);

  Stream<AspirantProfile?> watchAspirant(String userId) {
    return _user(userId).snapshots().map((doc) {
      final data = doc.data();
      if (data == null) return null;
      return AspirantProfile.fromMap(doc.id, data);
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

  /// Saves the whole Edit Profile form in one write.
  Future<void> saveAspirant({
    required String userId,
    required String name,
    required String username,
    required String bio,
    required String location,
    required String website,
    required Map<String, String> socialLinks,
    required AspirantFitnessStats fitnessStats,
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
      ...fitnessStats.toUpdate(),
      if (profilePhotoUrl != null) 'profilePhoto': profilePhotoUrl,
      if (coverPhotoUrl != null) 'coverPhoto': coverPhotoUrl,
    });
  }
}
