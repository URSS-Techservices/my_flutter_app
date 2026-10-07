import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class CloudinaryService {
  final cloudinary = CloudinaryPublic(
    'djzdaleib',     // 👈 Replace with your Cloudinary cloud name
    'flutter_upload',      // 👈 Replace with your upload preset
    cache: false,
  );

  Future<String?> uploadMedia(String filePath, {bool isVideo = false}) async {
    try {
      CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          filePath,
          resourceType: isVideo ? CloudinaryResourceType.Video : CloudinaryResourceType.Image,
        ),
      );
      return response.secureUrl; // 👈 This is the URL you’ll save in Firestore
    } on CloudinaryException catch (e) {
      print("Upload failed: ${e.message}");
      return null;
    }
  }
}
