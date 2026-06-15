import 'dart:typed_data';

import 'package:flutter/material.dart';

ImageProvider<Object> profileStoredImageProvider({
  required String? remoteUrl,
  String? localPath,
  Uint8List? localBytes,
}) {
  if (localBytes != null && localBytes.isNotEmpty) {
    return MemoryImage(localBytes);
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
  return (localBytes != null && localBytes.isNotEmpty) ||
      (remoteUrl != null && remoteUrl.isNotEmpty);
}
