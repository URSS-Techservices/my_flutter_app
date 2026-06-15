import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:halo/platform/image_editor_page_mobile.dart';
import 'package:image_picker/image_picker.dart';

Future<Uint8List?> openImageEditor(BuildContext context, XFile file) {
  return Navigator.push<Uint8List>(
    context,
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => AdvancedImageEditorPage(imagePath: file.path),
    ),
  );
}
