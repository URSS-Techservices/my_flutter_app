import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Firebase Storage + `users/{uid}` profile/cover update — shared by profile pages.
///
/// Storage path and field names match existing production behavior.
abstract final class ProfileMediaUpload {
  ProfileMediaUpload._();

  /// Uploads [file] to `users/{userId}/{cover|profile}_{userId}_{timestamp}` and
  /// writes `coverPhoto` or `profilePhoto` on the user document.
  static Future<String> uploadUserPhotoAndPersist({
    required FirebaseFirestore firestore,
    required String userId,
    required File file,
    required bool isCover,
  }) async {
    final fileName =
        '${isCover ? 'cover' : 'profile'}_${userId}_${DateTime.now().millisecondsSinceEpoch}';
    final ref = FirebaseStorage.instance
        .ref()
        .child('users')
        .child(userId)
        .child(fileName);
    final snap = await ref.putFile(file);
    final url = await snap.ref.getDownloadURL();
    final key = isCover ? 'coverPhoto' : 'profilePhoto';
    await firestore.collection('users').doc(userId).update({key: url});
    return url;
  }
}
