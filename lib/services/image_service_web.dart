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

  Future<AdaptiveImageSet> buildAdaptiveSetFromBytes(Uint8List bytes) async {
    final size = await _readImageSizeFromBytes(bytes);
    final originalWidth = size.$1;
    final originalHeight = size.$2;

    Uint8List? thumb;
    Uint8List? medium;
    Uint8List? full;

    if (originalWidth < 720) {
      medium = await _compressBytes(
        bytes,
        targetWidth: originalWidth,
        originalWidth: originalWidth,
        originalHeight: originalHeight,
      );
    } else if (originalWidth < 1080) {
      thumb = await _compressBytes(
        bytes,
        targetWidth: 300,
        originalWidth: originalWidth,
        originalHeight: originalHeight,
      );
      medium = await _compressBytes(
        bytes,
        targetWidth: 720,
        originalWidth: originalWidth,
        originalHeight: originalHeight,
      );
    } else {
      thumb = await _compressBytes(
        bytes,
        targetWidth: 300,
        originalWidth: originalWidth,
        originalHeight: originalHeight,
      );
      medium = await _compressBytes(
        bytes,
        targetWidth: 720,
        originalWidth: originalWidth,
        originalHeight: originalHeight,
      );
      full = await _compressBytes(
        bytes,
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

  Future<Uint8List> _compressBytes(
    Uint8List source, {
    required int targetWidth,
    required int originalWidth,
    required int originalHeight,
  }) async {
    final safeWidth = originalWidth < targetWidth ? originalWidth : targetWidth;
    final scaledHeight = (originalHeight * safeWidth / originalWidth).round();
    final bytes = await FlutterImageCompress.compressWithList(
      source,
      quality: _quality,
      minWidth: safeWidth,
      minHeight: scaledHeight,
      format: CompressFormat.webp,
    );
    if (bytes.isEmpty) {
      throw Exception('Image compression failed for width $targetWidth');
    }
    return bytes;
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
