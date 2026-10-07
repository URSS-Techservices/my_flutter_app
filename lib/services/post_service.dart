import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class PostService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadPostImage({
    required File imageFile,
    required String uid,
    required String postId,
  }) async {
    final ref = _storage.ref('users/$uid/posts/$postId.jpg');
    await ref.putFile(imageFile);
    return ref.getDownloadURL();
  }
}

Future<String> uploadPostImage({
  required File imageFile,
  required String uid,
  required String postId,
}) async {
  return PostService().uploadPostImage(
    imageFile: imageFile,
    uid: uid,
    postId: postId,
  );
}
