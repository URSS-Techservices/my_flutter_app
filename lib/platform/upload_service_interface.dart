import 'dart:typed_data';

import 'package:halo/platform/picked_media.dart';
import 'package:halo/platform/xfile_media.dart';
import 'package:image_picker/image_picker.dart';

/// Shared upload contract for HALO post/profile/story flows.
///
/// Mobile implementations use `File` + `putFile`.
/// Web implementations use [PickedMedia] / bytes + `putData`.
abstract class UploadServiceInterface {
  Future<Map<String, dynamic>> uploadAdaptivePostImage({
    required PickedMedia image,
    required String postId,
    required int index,
  });

  Future<Map<String, dynamic>> uploadVideoWithThumbnail({
    required PickedMedia video,
    required String postId,
    required int index,
    Uint8List? thumbnailBytes,
    int? trimStartMs,
    int? trimEndMs,
  });

  Future<String> uploadProfileImage({
    required PickedMedia image,
    required String uid,
  });
}

/// Normalize gallery/camera picks to [PickedMedia].
Future<PickedMedia> toPickedMedia(XFile file) => pickedMediaFromXFile(file);
