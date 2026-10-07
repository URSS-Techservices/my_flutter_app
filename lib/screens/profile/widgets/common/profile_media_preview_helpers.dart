import 'dart:io';

import 'package:flutter/material.dart';
import 'package:halo/widgets/profile_image_interactions.dart';

/// Full-screen image preview for profile/cover (local file takes precedence).
/// [heroTag] must stay aligned with the corresponding Hero in each profile page.
void openProfileStoredImagePreview({
  required BuildContext context,
  required File? localFile,
  required String? remoteUrl,
  required String heroTag,
}) {
  if (localFile == null && (remoteUrl == null || remoteUrl.isEmpty)) {
    return;
  }
  final ImageProvider<Object> provider = localFile != null
      ? FileImage(localFile)
      : NetworkImage(remoteUrl!);
  openProfileMediaPreview(
    context,
    image: provider,
    heroTag: heroTag,
  );
}
