import 'dart:io';

import 'package:flutter/material.dart';
import 'package:halo/platform/profile_local_photo.dart';
import 'package:image_picker/image_picker.dart';

/// Preview + confirm profile image pick (mobile — uses filesystem path).
Future<ProfileLocalPhoto?> editProfileImageWithInstagramStyle(
  BuildContext context, {
  required XFile picked,
  required String outputNamePrefix,
}) async {
  final confirmed = await Navigator.push<bool>(
    context,
    MaterialPageRoute(
      builder: (_) => _ProfileImagePreviewPage(imagePath: picked.path),
    ),
  );
  if (confirmed != true) return null;
  return ProfileLocalPhoto(path: picked.path);
}

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
                  GestureDetector(
                    onTap: () => Navigator.pop(context, false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Text(
                        'Retake',
                        style: TextStyle(color: Colors.white, fontSize: 15),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context, true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFA58CE3),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Text(
                        'Use Photo',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
