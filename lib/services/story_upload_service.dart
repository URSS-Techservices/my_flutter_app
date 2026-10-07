import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class StoryUploadService {
  final ImagePicker _picker = ImagePicker();

  /// Pick image or video and upload as a story
  Future<void> pickAndUploadStory({required bool isVideo}) async {
    final user = FirebaseAuth.instance.currentUser;

    // 🔒 STEP 1: Auth check
    if (user == null) {
      throw Exception('User not logged in');
    }

    XFile? pickedFile;

    // 🖼️ STEP 2: Pick media (IMAGE / VIDEO)
    if (isVideo) {
      pickedFile = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 30), // Instagram-like limit
      );
    } else {
      pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
    }

    if (pickedFile == null) return;

    final File file = File(pickedFile.path);

    // 🆔 STEP 3: Generate story ID
    final String storyId =
    DateTime.now().millisecondsSinceEpoch.toString();

    // 📂 STEP 4: Firebase Storage path
    final Reference storageRef = FirebaseStorage.instance
        .ref()
        .child('users')
        .child(user.uid)
        .child('stories')
        .child(isVideo ? '$storyId.mp4' : '$storyId.jpg');

    // ⬆️ STEP 5: Upload with correct metadata (IMPORTANT)
    await storageRef.putFile(
      file,
      SettableMetadata(
        contentType: isVideo ? 'video/mp4' : 'image/jpeg',
      ),
    );

    // 🔗 STEP 6: Get download URL
    final String downloadUrl = await storageRef.getDownloadURL();

    // 🗄️ STEP 7: Fetch user info
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final data = userDoc.data();

    final String username =
        (data?['username'] ??
            data?['name'] ??
            data?['full_name'] ??
            data?['business_name'])
            ?.toString()
            .trim() ??
            'User';

    final String userPhotoUrl =
        data?['profilePhoto']?.toString() ?? '';

    // 🗃️ STEP 8: Save story metadata to Firestore
    await FirebaseFirestore.instance
        .collection('stories')
        .doc(storyId)
        .set({
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

    // 🧪 DEBUG
    print('✅ Story uploaded successfully');
  }
}
