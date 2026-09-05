import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:halo/features/feed/presentation/home_layout.dart';
import 'package:halo/features/feed/presentation/media_aspect_data.dart';

/// Instagram-style photo: tiny preview first, then the feed-sized file.
class FittedPostImage extends ConsumerStatefulWidget {
  final String postId;
  final int index;
  final String url;
  final String thumbUrl;
  final int cacheWidth;

  const FittedPostImage({
    super.key,
    required this.postId,
    required this.index,
    required this.url,
    this.thumbUrl = '',
    required this.cacheWidth,
  });

  @override
  ConsumerState<FittedPostImage> createState() => _FittedPostImageState();
}

class _FittedPostImageState extends ConsumerState<FittedPostImage> {
  bool _probed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _probe());
  }

  @override
  Widget build(BuildContext context) {
    if (widget.url.isEmpty) {
      return const ColoredBox(color: HomeLayout.mediaFill);
    }

    return CachedNetworkImage(
      imageUrl: widget.url,
      fit: BoxFit.cover,
      alignment: Alignment.center,
      width: double.infinity,
      height: double.infinity,
      memCacheWidth: widget.cacheWidth,
      filterQuality: FilterQuality.high,
      fadeInDuration: const Duration(milliseconds: 120),
      placeholder: (_, __) => _Preview(url: widget.thumbUrl, fallback: widget.url),
      errorWidget: (_, __, ___) => const ColoredBox(
        color: HomeLayout.mediaError,
        child: Icon(Icons.broken_image_outlined, color: Colors.grey),
      ),
    );
  }

  void _probe() {
    if (!mounted || _probed || widget.url.isEmpty) return;
    _probed = true;
    final stream = CachedNetworkImageProvider(widget.url)
        .resolve(const ImageConfiguration());
    late final ImageStreamListener listener;
    listener = ImageStreamListener((info, _) {
      stream.removeListener(listener);
      final w = info.image.width;
      final h = info.image.height;
      if (w <= 0 || h <= 0 || !mounted) return;
      reportMediaAspect(
        ref,
        isMounted: () => mounted,
        postId: widget.postId,
        index: widget.index,
        aspect: w / h,
      );
    });
    stream.addListener(listener);
  }
}

class _Preview extends StatelessWidget {
  final String url;
  final String fallback;

  const _Preview({required this.url, required this.fallback});

  @override
  Widget build(BuildContext context) {
    final src = url.isNotEmpty ? url : fallback;
    if (src.isEmpty) {
      return const ColoredBox(color: HomeLayout.mediaFill);
    }
    return CachedNetworkImage(
      imageUrl: src,
      fit: BoxFit.cover,
      alignment: Alignment.center,
      width: double.infinity,
      height: double.infinity,
      memCacheWidth: 96,
      filterQuality: FilterQuality.low,
      fadeInDuration: Duration.zero,
      placeholder: (_, __) => const ColoredBox(color: HomeLayout.mediaFill),
      errorWidget: (_, __, ___) => const ColoredBox(color: HomeLayout.mediaFill),
    );
  }
}
