import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

Future<XFile?> xFileFromEditedBytes(Uint8List editedBytes) async {
  final newPath =
      '${Directory.systemTemp.path}/halo_edit_${DateTime.now().microsecondsSinceEpoch}.jpg';
  final editedFile = File(newPath);
  await editedFile.writeAsBytes(editedBytes, flush: true);
  return XFile(newPath);
}

void cleanupTempPaths(List<String> paths) {
  for (final path in paths) {
    try {
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
    } catch (_) {}
  }
}

Future<void> deletePathIfExists(String path) async {
  try {
    final file = File(path);
    if (await file.exists()) await file.delete();
  } catch (_) {}
}

Widget buildLocalPathImage(String path, {BoxFit fit = BoxFit.cover}) {
  return Image.file(File(path), fit: fit);
}

VideoPlayerController createFileVideoController(String path) {
  return VideoPlayerController.file(File(path));
}

bool pathExists(String path) => File(path).existsSync();
