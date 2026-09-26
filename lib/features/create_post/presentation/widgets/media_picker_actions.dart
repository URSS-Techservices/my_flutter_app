import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:halo/core/halo_theme.dart';

class MediaPickerActions extends StatelessWidget {
  final VoidCallback? onGallery;
  final VoidCallback? onCamera;
  final VoidCallback? onVideo;

  const MediaPickerActions({
    super.key,
    required this.onGallery,
    required this.onCamera,
    required this.onVideo,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _MediaButton(icon: Icons.photo_library_rounded, label: 'Gallery', color: kPrimaryColor, onTap: onGallery),
        const SizedBox(width: 12),
        _MediaButton(icon: Icons.camera_alt_rounded, label: 'Camera', color: kSecondaryColor, onTap: onCamera),
        const SizedBox(width: 12),
        _MediaButton(
          icon: Icons.video_library_rounded,
          label: 'Video',
          color: const Color(0xFFD3F8E2),
          onTap: onVideo,
        ),
      ],
    );
  }
}

class _MediaButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _MediaButton({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDisabled = onTap == null;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          height: 100,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withValues(alpha: 0.9), color.withValues(alpha: 0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDisabled ? Colors.grey.shade300 : color.withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: isDisabled
                ? []
                : [
                    BoxShadow(
                      color: color.withValues(alpha: 0.2),
                      blurRadius: 12,
                      spreadRadius: -2,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Icon(icon, color: isDisabled ? Colors.grey.shade400 : kSecondaryColor, size: 26),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDisabled ? Colors.grey.shade400 : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
