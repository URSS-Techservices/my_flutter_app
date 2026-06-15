import 'package:flutter/material.dart';
import 'package:halo/platform/media_preview.dart';
import 'package:halo/platform/profile_local_photo.dart';

/// Resolves cover/avatar [ImageProvider] from local pick, remote URL, or asset.
ImageProvider<Object> profileHeroImageProvider({
  ProfileLocalPhoto? local,
  String? remoteUrl,
  required ImageProvider<Object> defaultAsset,
}) {
  if (local != null && local.hasPreview) {
    return profileStoredImageProvider(
      remoteUrl: null,
      localPath: local.previewBytes == null ? local.path : null,
      localBytes: local.previewBytes,
    );
  }
  if (remoteUrl != null && remoteUrl.isNotEmpty) {
    return NetworkImage(remoteUrl);
  }
  return defaultAsset;
}
