import 'package:flutter/material.dart';

class MediaLocationPill extends StatelessWidget {
  final String text;

  const MediaLocationPill({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.55,
        ),
        child: _GlassBox(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_on_rounded, size: 12, color: Colors.white),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _pillStyle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MediaPageDots extends StatelessWidget {
  final int count;
  final int index;

  const MediaPageDots({
    super.key,
    required this.count,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(count, (i) {
          final on = i == index;
          return Container(
            width: on ? 7 : 6,
            height: on ? 7 : 6,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: on ? Colors.white : Colors.white.withValues(alpha: 0.45),
              boxShadow: const [
                BoxShadow(color: Colors.black38, blurRadius: 3),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class MediaLikeBurst extends StatelessWidget {
  const MediaLikeBurst({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(Icons.favorite_rounded, color: Colors.white, size: 88),
    );
  }
}

class MediaMuteButton extends StatelessWidget {
  final bool muted;
  final VoidCallback onTap;

  const MediaMuteButton({
    super.key,
    required this.muted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: const BoxDecoration(
          color: Color(0x8C000000),
          shape: BoxShape.circle,
        ),
        child: Icon(
          muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
          color: Colors.white,
          size: 18,
        ),
      ),
    );
  }
}

/// Page index, location, dots, and double-tap heart — no media logic here.
class PostMediaChrome extends StatelessWidget {
  final int page;
  final int count;
  final String location;
  final bool showHeart;

  const PostMediaChrome({
    super.key,
    required this.page,
    required this.count,
    required this.location,
    required this.showHeart,
  });

  @override
  Widget build(BuildContext context) {
    final multi = count > 1;
    final place = location.trim();
    return Stack(
      children: [
        if (multi)
          Positioned(
            top: 10,
            right: 10,
            child: _GlassBox(
              child: Text('${page + 1}/$count', style: _pillStyle),
            ),
          ),
        if (place.isNotEmpty)
          Positioned(
            left: 10,
            bottom: multi ? 28 : 10,
            child: MediaLocationPill(text: place),
          ),
        if (multi)
          Positioned(
            left: 0,
            right: 0,
            bottom: 8,
            child: MediaPageDots(count: count, index: page),
          ),
        if (showHeart) const MediaLikeBurst(),
      ],
    );
  }
}

const _pillStyle = TextStyle(
  color: Colors.white,
  fontSize: 11,
  fontWeight: FontWeight.w600,
);

class _GlassBox extends StatelessWidget {
  final Widget child;

  const _GlassBox({required this.child});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(20),
        ),
        child: child,
      ),
    );
  }
}
