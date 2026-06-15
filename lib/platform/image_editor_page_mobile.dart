import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

/// Mobile image editor — unchanged pro_image_editor flow.
class AdvancedImageEditorPage extends StatelessWidget {
  final String imagePath;

  const AdvancedImageEditorPage({super.key, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: ProImageEditor.file(
        File(imagePath),
        configs: ProImageEditorConfigs(
          imageGeneration: const ImageGenerationConfigs(
            outputFormat: OutputFormat.jpg,
            maxOutputSize: Size(1280, 1280),
          ),
        ),
        callbacks: ProImageEditorCallbacks(
          onImageEditingComplete: (Uint8List bytes) async {
            if (!context.mounted) return;
            Navigator.pop(context, bytes);
          },
        ),
      ),
    );
  }
}
