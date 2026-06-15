import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Web fallback — preview only; returns original bytes without native editor.
class AdvancedImageEditorPage extends StatelessWidget {
  final String imagePath;
  final Uint8List imageBytes;

  const AdvancedImageEditorPage({
    super.key,
    required this.imagePath,
    required this.imageBytes,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('Preview', style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, imageBytes),
            child: Text(
              'Use photo',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
      body: Center(
        child: Image.memory(imageBytes, fit: BoxFit.contain),
      ),
    );
  }
}
