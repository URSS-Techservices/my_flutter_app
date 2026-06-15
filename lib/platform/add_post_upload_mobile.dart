import 'dart:io';
import 'dart:typed_data';

import 'package:halo/services/upload_service.dart';
import 'package:halo/services/video_upload_policy.dart';
import 'package:image_picker/image_picker.dart';

Future<Map<String, dynamic>> uploadDraftMedia({
  required UploadService uploadService,
  required XFile file,
  required bool isVideo,
  required String postId,
  required int index,
  Uint8List? videoCoverBytes,
  int? trimStartMs,
  int? trimEndMs,
  Uint8List? cachedBytes,
}) {
  if (isVideo) {
    return uploadService.uploadVideoWithThumbnail(
      videoFile: File(file.path),
      postId: postId,
      index: index,
      thumbnailBytes: videoCoverBytes,
      trimStartMs: trimStartMs,
      trimEndMs: trimEndMs,
    );
  }
  return uploadService.uploadAdaptivePostImage(
    imageFile: File(file.path),
    postId: postId,
    index: index,
  );
}

Future<bool> isVideoAllowedForUpload(String path) async {
  final rejection = await VideoUploadPolicy.validateFile(File(path));
  return rejection == null;
}
