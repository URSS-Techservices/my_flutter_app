import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:halo/platform/storage_upload.dart';
import 'package:image_picker/image_picker.dart';

class StoryUploadService {
  final ImagePicker _picker = ImagePicker();

  /// Pick image or video and upload as a story.
  Future<void> pickAndUploadStory({required bool isVideo}) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('User not logged in');
    }

    XFile? pickedFile;

    if (isVideo) {
      pickedFile = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 30),
      );
    } else {
      pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
    }

    if (pickedFile == null) return;

    final storyId = DateTime.now().millisecondsSinceEpoch.toString();

    final storageRef = FirebaseStorage.instance
        .ref()
        .child('users')
        .child(user.uid)
        .child('stories')
        .child(isVideo ? '$storyId.mp4' : '$storyId.jpg');

    await uploadReferenceXFile(
      storageRef,
      pickedFile,
      metadata: SettableMetadata(
        contentType: isVideo ? 'video/mp4' : 'image/jpeg',
      ),
    );

    final downloadUrl = await storageRef.getDownloadURL();

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final data = userDoc.data();

    final username = (data?['username'] ??
            data?['name'] ??
            data?['full_name'] ??
            data?['business_name'])
        ?.toString()
        .trim() ??
        'User';

    final userPhotoUrl = data?['profilePhoto']?.toString() ?? '';

    await FirebaseFirestore.instance.collection('stories').doc(storyId).set({
      'id': storyId,
      'userId': user.uid,
      'username': username,
      'userPhotoUrl': userPhotoUrl,
      'mediaUrl': downloadUrl,
      'mediaType': isVideo ? 'video' : 'image',
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(hours: 24)),
      ),
      'viewers': [],
    });
  }
}
