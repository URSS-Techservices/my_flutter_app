import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Opens a simple crop/preview page for profile images.
/// Returns the edited file or null if cancelled.
/// (pro_image_editor removed — requires Dart ≥3.11, we run 3.10)
Future<File?> editProfileImageWithInstagramStyle(
  BuildContext context, {
  required String imagePath,
  required String outputNamePrefix,
}) async {
  // Lightweight preview — user can retake if they don't like it.
  // A full crop editor will be added once the project upgrades to Flutter 3.44+.
  final confirmed = await Navigator.push<bool>(
    context,
    MaterialPageRoute(
      builder: (_) => _ProfileImagePreviewPage(imagePath: imagePath),
    ),
  );
  if (confirmed != true) return null;
  return File(imagePath);
}

void openProfileMediaPreview(
  BuildContext context, {
  required ImageProvider image,
  required String heroTag,
}) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => _ProfileMediaPreviewPage(image: image, heroTag: heroTag),
    ),
  );
}

// ── Simple preview + confirm/retake page ────────────────────────────────────

class _ProfileImagePreviewPage extends StatelessWidget {
  final String imagePath;
  const _ProfileImagePreviewPage({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: Image.file(File(imagePath), fit: BoxFit.contain),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Retake
                  GestureDetector(
                    onTap: () => Navigator.pop(context, false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Text('Retake',
                          style: TextStyle(color: Colors.white, fontSize: 15)),
                    ),
                  ),
                  // Use photo
                  GestureDetector(
                    onTap: () => Navigator.pop(context, true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFA58CE3),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Text('Use Photo',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileMediaPreviewPage extends StatelessWidget {
  final ImageProvider image;
  final String heroTag;

  const _ProfileMediaPreviewPage({
    required this.image,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: Hero(
              tag: heroTag,
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Image(image: image, fit: BoxFit.contain),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
