import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:halo/core/halo_theme.dart';
import 'package:halo/features/create_post/domain/media_asset.dart';
import 'package:halo/features/create_post/presentation/add_post_controller.dart';

/// Contextual "Uploading 2 of 5" strip instead of one blind full-screen
/// spinner, driven entirely by real per-asset upload progress.
class UploadProgress extends ConsumerWidget {
  const UploadProgress({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSubmitting = ref.watch(addPostControllerProvider.select((s) => s.isSubmitting));
    if (!isSubmitting) return const SizedBox.shrink();

    final media = ref.watch(addPostControllerProvider.select((s) => s.media));
    final total = media.length;
    final done = media.where((a) => a.status == MediaStatus.uploaded).length;
    final overallProgress = total == 0 ? 0.0 : media.fold<double>(0, (sum, a) => sum + a.uploadProgress) / total;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: kPrimaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Uploading ${done + 1 > total ? total : done + 1} of $total',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12, color: kSecondaryColor),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: overallProgress,
              minHeight: 6,
              backgroundColor: kPrimaryColor.withValues(alpha: 0.15),
              color: kSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }
}
