import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:halo/platform/media_preview.dart';
import 'package:halo/widgets/profile_image_interactions.dart';

/// Full-screen image preview for profile/cover (local bytes/path take precedence).
void openProfileStoredImagePreview({
  required BuildContext context,
  String? localPath,
  Uint8List? localBytes,
  required String? remoteUrl,
  required String heroTag,
}) {
  if (!hasLocalProfilePreview(
    localPath: localPath,
    localBytes: localBytes,
    remoteUrl: remoteUrl,
  )) {
    return;
  }
  final provider = profileStoredImageProvider(
    remoteUrl: remoteUrl,
    localPath: localPath,
    localBytes: localBytes,
  );
  openProfileMediaPreview(
    context,
    image: provider,
    heroTag: heroTag,
  );
}
