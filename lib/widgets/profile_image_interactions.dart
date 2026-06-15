import 'package:flutter/material.dart';

export 'package:halo/platform/profile_image_editor.dart'
    show editProfileImageWithInstagramStyle;

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
