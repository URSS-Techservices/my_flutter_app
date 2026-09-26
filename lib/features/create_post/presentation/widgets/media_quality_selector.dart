import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:halo/core/halo_theme.dart';
import 'package:halo/features/create_post/domain/media_quality_profile.dart';

String formatBytes(int bytes) {
  if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// Bottom sheet shown only when a picked file is large enough to matter.
/// Deliberately shows no fabricated "estimated result" size — only the
/// original size and an honest description of what each profile does.
Future<MediaQualityProfile?> showMediaQualitySelector(
  BuildContext context, {
  required bool isVideo,
  required int originalBytes,
}) {
  return showModalBottomSheet<MediaQualityProfile>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => _MediaQualitySheet(isVideo: isVideo, originalBytes: originalBytes),
  );
}

class _MediaQualitySheet extends StatefulWidget {
  final bool isVideo;
  final int originalBytes;

  const _MediaQualitySheet({required this.isVideo, required this.originalBytes});

  @override
  State<_MediaQualitySheet> createState() => _MediaQualitySheetState();
}

class _MediaQualitySheetState extends State<_MediaQualitySheet> {
  MediaQualityProfile _selected = MediaQualityProfile.balanced;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.isVideo ? 'Optimize this video?' : 'Optimize this photo?',
              style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Original size: ${formatBytes(widget.originalBytes)}',
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 16),
            for (final profile in MediaQualityProfile.values) _buildOption(profile),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, _selected),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kSecondaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(MediaQualityProfile profile) {
    final selected = _selected == profile;
    return GestureDetector(
      onTap: () => setState(() => _selected = profile),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? kPrimaryColor.withValues(alpha: 0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? kPrimaryColor : Colors.grey.shade300, width: selected ? 2 : 1),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: selected ? kSecondaryColor : Colors.grey.shade400,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(profile.label, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(
                    profile.description,
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
