import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// Local profile/cover pick before or after upload — works on mobile and web.
class ProfileLocalPhoto {
  final String path;
  final Uint8List? previewBytes;

  const ProfileLocalPhoto({
    required this.path,
    this.previewBytes,
  });

  bool get hasPreview =>
      (previewBytes != null && previewBytes!.isNotEmpty) || path.isNotEmpty;

  /// Upload-ready [XFile] — bytes on web, filesystem path on mobile.
  Future<XFile> toXFile() async {
    if (kIsWeb && previewBytes != null && previewBytes!.isNotEmpty) {
      return XFile.fromData(
        previewBytes!,
        mimeType: 'image/jpeg',
        name: 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
    }
    return XFile(path);
  }
}
