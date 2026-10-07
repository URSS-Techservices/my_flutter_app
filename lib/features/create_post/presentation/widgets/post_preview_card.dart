import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:halo/core/halo_theme.dart';
import 'package:halo/features/create_post/domain/media_asset.dart';
import 'package:halo/features/create_post/presentation/add_post_controller.dart';

class PostPreviewCard extends ConsumerWidget {
  const PostPreviewCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(addPostControllerProvider);
    final hasMedia = draft.media.isNotEmpty;
    final caption = draft.caption.trim();
    final location = draft.location.trim();

    if (!hasMedia && caption.isEmpty && location.isEmpty && draft.tags.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Preview', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.black)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(blurRadius: 22, spreadRadius: -12, offset: const Offset(0, 16), color: Colors.black.withValues(alpha: 0.08)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  leading: const CircleAvatar(backgroundImage: AssetImage('assets/images/Profile.png'), radius: 18),
                  title: Text(
                    location.isNotEmpty ? location : 'Location',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text('Just now', style: TextStyle(color: Colors.black87)),
                  trailing: const Icon(Icons.more_horiz_rounded),
                ),
                if (hasMedia)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: _PreviewMediaCarousel(media: draft.media),
                  ),
                Padding(
                  padding: const EdgeInsets.only(left: 4, right: 4, top: 4, bottom: 4),
                  child: Row(
                    children: [
                      IconButton(icon: const Icon(Icons.favorite_border), onPressed: () {}),
                      IconButton(icon: const Icon(Icons.message_outlined), onPressed: () {}),
                      IconButton(icon: const Icon(Icons.share), onPressed: () {}),
                      const Spacer(),
                      IconButton(icon: const Icon(Icons.bookmark_border), onPressed: () {}),
                    ],
                  ),
                ),
                if (draft.tags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: -4,
                      children: draft.tags
                          .map(
                            (tag) => Chip(
                              label: Text(tag, style: GoogleFonts.poppins(color: kSecondaryColor, fontWeight: FontWeight.w500)),
                              backgroundColor: kPrimaryColor.withValues(alpha: 0.10),
                              side: BorderSide(color: kPrimaryColor.withValues(alpha: 0.4)),
                              visualDensity: VisualDensity.compact,
                            ),
                          )
                          .toList(),
                    ),
                  ),
                if (caption.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: _highlightedCaption(caption),
                  ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _highlightedCaption(String text) {
    final baseStyle = GoogleFonts.poppins(color: Colors.black, fontSize: 14);
    final words = text.split(RegExp(r'(\s+)'));
    return Text.rich(
      TextSpan(
        children: words.map((w) {
          if (w.startsWith('@') && w.length > 1) {
            return TextSpan(text: w, style: baseStyle.copyWith(color: kSecondaryColor, fontWeight: FontWeight.w600));
          }
          return TextSpan(text: w, style: baseStyle);
        }).toList(),
      ),
    );
  }
}

/// Swipeable preview of every selected media item, in the same order the
/// real post will show them — not just the first one.
class _PreviewMediaCarousel extends StatefulWidget {
  final List<MediaAsset> media;
  const _PreviewMediaCarousel({required this.media});

  @override
  State<_PreviewMediaCarousel> createState() => _PreviewMediaCarouselState();
}

class _PreviewMediaCarouselState extends State<_PreviewMediaCarousel> {
  final _pc = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.media;
    final page = _page < items.length ? _page : 0;
    return SizedBox(
      height: 260,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pc,
            itemCount: items.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) => _tile(items[i]),
          ),
          if (items.length > 1)
            Positioned(
              top: 10,
              right: 10,
              child: _pill('${page + 1}/${items.length}'),
            ),
          if (items.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 8,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(items.length, (i) {
                  final on = i == page;
                  return Container(
                    width: on ? 7 : 6,
                    height: on ? 7 : 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: on ? Colors.white : Colors.white.withValues(alpha: 0.45),
                      boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 3)],
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tile(MediaAsset asset) {
    if (asset.isImage) {
      return Image.file(asset.originalFile, fit: BoxFit.cover, width: double.infinity, height: double.infinity);
    }
    if (asset.coverBytes != null) {
      return Image.memory(asset.coverBytes!, fit: BoxFit.cover, width: double.infinity, height: double.infinity);
    }
    return Container(
      color: Colors.black87,
      child: const Center(child: Icon(Icons.videocam_rounded, color: Colors.white, size: 40)),
    );
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
