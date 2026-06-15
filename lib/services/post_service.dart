import 'package:firebase_storage/firebase_storage.dart';
import 'package:halo/platform/picked_media.dart';
import 'package:halo/platform/storage_upload.dart';
import 'package:halo/platform/xfile_media.dart';
import 'package:image_picker/image_picker.dart';

class PostService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadPostImage({
    required PickedMedia image,
    required String uid,
    required String postId,
  }) async {
    final ref = _storage.ref('users/$uid/posts/$postId.jpg');
    await uploadReferencePicked(
      ref,
      image,
      metadata: SettableMetadata(contentType: 'image/jpeg'),
    );
    return ref.getDownloadURL();
  }

  Future<String> uploadPostImageFromXFile({
    required XFile imageFile,
    required String uid,
    required String postId,
  }) async {
    final picked = await pickedMediaFromXFile(imageFile);
    return uploadPostImage(image: picked, uid: uid, postId: postId);
  }
}

Future<String> uploadPostImage({
  required PickedMedia image,
  required String uid,
  required String postId,
}) async {
  return PostService().uploadPostImage(
    image: image,
    uid: uid,
    postId: postId,
  );
}
