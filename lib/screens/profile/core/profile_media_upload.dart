import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:halo/platform/storage_upload.dart';
import 'package:image_picker/image_picker.dart';

/// Firebase Storage + `users/{uid}` profile/cover update — shared by profile pages.
///
/// Storage path and field names match existing production behavior.
abstract final class ProfileMediaUpload {
  ProfileMediaUpload._();

  /// Uploads [media] to `users/{userId}/{cover|profile}_{userId}_{timestamp}` and
  /// writes `coverPhoto` or `profilePhoto` on the user document.
  static Future<String> uploadUserPhotoAndPersist({
    required FirebaseFirestore firestore,
    required String userId,
    required XFile media,
    required bool isCover,
  }) async {
    final fileName =
        '${isCover ? 'cover' : 'profile'}_${userId}_${DateTime.now().millisecondsSinceEpoch}';
    final ref = FirebaseStorage.instance
        .ref()
        .child('users')
        .child(userId)
        .child(fileName);

    final url = await uploadReferenceXFileAndGetUrl(
      ref,
      media,
      metadata: SettableMetadata(
        contentType: media.mimeType ?? 'image/jpeg',
      ),
    );

    final key = isCover ? 'coverPhoto' : 'profilePhoto';
    await firestore.collection('users').doc(userId).update({key: url});
    return url;
  }
}
