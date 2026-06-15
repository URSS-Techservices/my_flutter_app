import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

ImageProvider<Object> profileStoredImageProvider({
  required String? remoteUrl,
  String? localPath,
  Uint8List? localBytes,
}) {
  if (localPath != null && localPath.isNotEmpty) {
    return FileImage(File(localPath));
  }
  if (remoteUrl != null && remoteUrl.isNotEmpty) {
    return NetworkImage(remoteUrl);
  }
  throw ArgumentError('No image source available');
}

bool hasLocalProfilePreview({
  String? localPath,
  Uint8List? localBytes,
  String? remoteUrl,
}) {
  return (localPath != null && localPath.isNotEmpty) ||
      (remoteUrl != null && remoteUrl.isNotEmpty);
}
