import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:halo/core/halo_theme.dart';
import 'package:halo/features/create_post/domain/media_asset.dart';
import 'package:halo/features/create_post/presentation/add_post_controller.dart';

/// Reorderable strip of selected media with a per-item status overlay
/// (processing/uploading/failed) so the user always knows what's happening
/// to each file — no single blind spinner for the whole post.
class MediaGrid extends ConsumerWidget {
  const MediaGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = ref.watch(addPostControllerProvider.select((s) => s.media));

    if (media.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade200, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_outlined, color: Colors.grey.shade400, size: 24),
            const SizedBox(width: 12),
            Text(
              'No media selected yet',
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.black87, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kPrimaryColor.withValues(alpha: 0.2), width: 1.5),
      ),
      child: SizedBox(
        height: 116,
        child: ReorderableListView.builder(
          scrollDirection: Axis.horizontal,
          buildDefaultDragHandles: false,
          itemCount: media.length,
          onReorder: (oldIndex, newIndex) =>
              ref.read(addPostControllerProvider.notifier).reorderMedia(oldIndex, newIndex),
          itemBuilder: (context, index) {
            final asset = media[index];
            // Delayed (long-press) drag start — a plain touch-and-move still
            // scrolls the strip normally; only a held press starts reordering.
            return ReorderableDelayedDragStartListener(
              key: ValueKey(asset.id),
              index: index,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6.0),
                child: _MediaTile(asset: asset, position: index + 1, showPosition: media.length > 1),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MediaTile extends ConsumerWidget {
  final MediaAsset asset;
  final int position;
  final bool showPosition;
  const _MediaTile({required this.asset, required this.position, required this.showPosition});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      children: [
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: _thumbnail(),
          ),
        ),
        if (showPosition)
          Positioned(
            top: 6,
            left: 6,
            child: Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: position == 1 ? kSecondaryColor : Colors.black.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: Text(
                '$position',
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        if (asset.status != MediaStatus.ready && asset.status != MediaStatus.uploaded) _statusOverlay(context, ref),
        if (asset.status != MediaStatus.uploading)
          Positioned(
            top: 6,
            right: 6,
            child: GestureDetector(
              onTap: () => ref.read(addPostControllerProvider.notifier).removeMedia(asset.id),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2))],
                ),
                child: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
              ),
            ),
          ),
        if (asset.isVideo)
          const Positioned(
            bottom: 6,
            left: 6,
            child: Icon(Icons.videocam_rounded, color: Colors.white, size: 18, shadows: [Shadow(blurRadius: 4)]),
          ),
      ],
    );
  }

  Widget _thumbnail() {
    if (asset.isVideo && asset.coverBytes != null) {
      return Image.memory(asset.coverBytes!, width: 110, height: 110, fit: BoxFit.cover);
    }
    if (asset.isImage) {
      return Image.file(asset.originalFile, width: 110, height: 110, fit: BoxFit.cover);
    }
    return Container(
      width: 110,
      height: 110,
      color: Colors.black87,
      child: const Center(child: Icon(Icons.videocam_rounded, color: Colors.white, size: 32)),
    );
  }

  Widget _statusOverlay(BuildContext context, WidgetRef ref) {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: switch (asset.status) {
            MediaStatus.validating || MediaStatus.processing => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    asset.status == MediaStatus.processing ? 'Optimizing...' : 'Checking...',
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 10),
                  ),
                ],
              ),
            MediaStatus.uploading => SizedBox(
                width: 36,
                height: 36,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      strokeWidth: 3,
                      value: asset.uploadProgress > 0 ? asset.uploadProgress : null,
                      color: Colors.white,
                      backgroundColor: Colors.white24,
                    ),
                    Text(
                      '${(asset.uploadProgress * 100).round()}%',
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            MediaStatus.failed => GestureDetector(
                onTap: () => ref.read(addPostControllerProvider.notifier).retryAsset(asset.id),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                    const SizedBox(height: 4),
                    Text('Retry', style: GoogleFonts.poppins(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            _ => const SizedBox.shrink(),
          },
        ),
      ),
    );
  }
}
