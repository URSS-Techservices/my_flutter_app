import 'dart:io';
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
  return Image.file(
    File(path),
    fit: fit,
    cacheWidth: cacheWidth,
    cacheHeight: cacheHeight,
    filterQuality: filterQuality,
    width: width,
    height: height,
    gaplessPlayback: true,
  );
}

VideoPlayerController createDraftVideoController(String path) {
  return VideoPlayerController.file(File(path));
}
