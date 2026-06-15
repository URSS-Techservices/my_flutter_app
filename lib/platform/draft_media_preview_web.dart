import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

Widget buildDraftImagePreview(
  String path, {
  BoxFit fit = BoxFit.cover,
  int? cacheWidth,
  int? cacheHeight,
  FilterQuality filterQuality = FilterQuality.none,
  double? width,
  double? height,
  Uint8List? previewBytes,
}) {
  if (previewBytes != null && previewBytes.isNotEmpty) {
    return Image.memory(
      previewBytes,
      fit: fit,
      filterQuality: filterQuality,
      width: width,
      height: height,
      gaplessPlayback: true,
    );
  }
  return const Center(
    child: Icon(Icons.image_outlined, color: Colors.white54, size: 40),
  );
}

VideoPlayerController createDraftVideoController(String path) {
  final uri = Uri.tryParse(path);
  if (uri != null && (uri.scheme == 'blob' || uri.scheme == 'http' || uri.scheme == 'https')) {
    return VideoPlayerController.networkUrl(uri);
  }
  return VideoPlayerController.networkUrl(Uri.parse(path));
}
