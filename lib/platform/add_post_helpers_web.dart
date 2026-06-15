import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

Future<XFile?> xFileFromEditedBytes(Uint8List editedBytes) async {
  return XFile.fromData(
    editedBytes,
    mimeType: 'image/jpeg',
    name: 'halo_edit_${DateTime.now().microsecondsSinceEpoch}.jpg',
  );
}

void cleanupTempPaths(List<String> paths) {}

Future<void> deletePathIfExists(String path) async {}

Widget buildLocalPathImage(
  String path, {
  BoxFit fit = BoxFit.cover,
  Uint8List? bytes,
}) {
  if (bytes != null && bytes.isNotEmpty) {
    return Image.memory(bytes, fit: fit);
  }
  return const SizedBox.shrink();
}

VideoPlayerController? createFileVideoController(String path) => null;

bool pathExists(String path) => false;
