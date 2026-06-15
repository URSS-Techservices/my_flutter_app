import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:halo/platform/image_editor_page_web.dart';
import 'package:image_picker/image_picker.dart';

Future<Uint8List?> openImageEditor(BuildContext context, XFile file) async {
  final bytes = await file.readAsBytes();
  if (!context.mounted) return null;
  return Navigator.push<Uint8List>(
    context,
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => AdvancedImageEditorPage(
        imagePath: file.path,
        imageBytes: bytes,
      ),
    ),
  );
}
