import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_image_compress/flutter_image_compress.dart';

class AdaptiveImageSet {
  final Uint8List? thumbBytes;
  final Uint8List? mediumBytes;
  final Uint8List? fullBytes;
  final int originalWidth;
  final int originalHeight;

  const AdaptiveImageSet({
    required this.thumbBytes,
    required this.mediumBytes,
    required this.fullBytes,
    required this.originalWidth,
    required this.originalHeight,
  });

  bool get hasThumb => thumbBytes != null && thumbBytes!.isNotEmpty;
  bool get hasMedium => mediumBytes != null && mediumBytes!.isNotEmpty;
  bool get hasFull => fullBytes != null && fullBytes!.isNotEmpty;
}

class ImageService {
  static const int _quality = 93;

  Future<AdaptiveImageSet> buildAdaptiveSet(File imageFile) async {
    final source = imageFile.path;
    final size = await _readImageSize(imageFile);
    final originalWidth = size.$1;
    final originalHeight = size.$2;

    Uint8List? thumb;
    Uint8List? medium;
    Uint8List? full;

    if (originalWidth < 720) {
      medium = await _compressToWidth(
        source,
        targetWidth: originalWidth,
        originalWidth: originalWidth,
        originalHeight: originalHeight,
      );
    } else if (originalWidth < 1080) {
      thumb = await _compressToWidth(
        source,
        targetWidth: 300,
        originalWidth: originalWidth,
        originalHeight: originalHeight,
      );
      medium = await _compressToWidth(
        source,
        targetWidth: 720,
        originalWidth: originalWidth,
        originalHeight: originalHeight,
      );
    } else {
      thumb = await _compressToWidth(
        source,
        targetWidth: 300,
        originalWidth: originalWidth,
        originalHeight: originalHeight,
      );
      medium = await _compressToWidth(
        source,
        targetWidth: 720,
        originalWidth: originalWidth,
        originalHeight: originalHeight,
      );
      full = await _compressToWidth(
        source,
        targetWidth: 1080,
        originalWidth: originalWidth,
        originalHeight: originalHeight,
      );
    }

    return AdaptiveImageSet(
      thumbBytes: thumb,
      mediumBytes: medium,
      fullBytes: full,
      originalWidth: originalWidth,
      originalHeight: originalHeight,
    );
  }

  Future<Uint8List> _compressToWidth(
    String path, {
    required int targetWidth,
    required int originalWidth,
    required int originalHeight,
  }) async {
    final safeWidth = originalWidth < targetWidth ? originalWidth : targetWidth;
    final scaledHeight = (originalHeight * safeWidth / originalWidth).round();
    final bytes = await FlutterImageCompress.compressWithFile(
      path,
      quality: _quality,
      minWidth: safeWidth,
      minHeight: scaledHeight,
      keepExif: true,
      format: CompressFormat.webp,
    );
    if (bytes == null || bytes.isEmpty) {
      throw Exception('Image compression failed for width $targetWidth');
    }
    return bytes;
  }

  Future<(int, int)> _readImageSize(File file) async {
    final bytes = await file.readAsBytes();
    return _readImageSizeFromBytes(bytes);
  }

  Future<(int, int)> _readImageSizeFromBytes(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final width = frame.image.width;
    final height = frame.image.height;
    frame.image.dispose();
    codec.dispose();
    return (width, height);
  }
}
