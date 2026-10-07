import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Instant Instagram-style heart. Pops on like; UI never waits on the network.
class InstantHeartButton extends StatefulWidget {
  final bool liked;
  final Color likedColor;
  final Color idleColor;
  final double size;
  final VoidCallback? onTap;

  const InstantHeartButton({
    super.key,
    required this.liked,
    this.likedColor = const Color(0xFFE53935),
    this.idleColor = const Color(0xFF262626),
    required this.size,
    this.onTap,
  });

  @override
  State<InstantHeartButton> createState() => _InstantHeartButtonState();
}

class _InstantHeartButtonState extends State<InstantHeartButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1, end: 1.28), weight: 40),
    TweenSequenceItem(tween: Tween(begin: 1.28, end: 0.9), weight: 28),
    TweenSequenceItem(tween: Tween(begin: 0.9, end: 1), weight: 32),
  ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

  @override
  void didUpdateWidget(covariant InstantHeartButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.liked && widget.liked) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap == null
          ? null
          : () {
              HapticFeedback.lightImpact();
              widget.onTap!();
            },
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: ScaleTransition(
          scale: _scale,
          child: Icon(
            widget.liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            size: widget.size,
            color: widget.liked ? widget.likedColor : widget.idleColor,
          ),
        ),
      ),
    );
  }
}

/// Compact comment heart — count sits under the icon, not beside the post actions.
class CommentHeartButton extends StatelessWidget {
  final bool liked;
  final int count;
  final VoidCallback? onLike;
  final VoidCallback? onShowLikers;

  const CommentHeartButton({
    super.key,
    required this.liked,
    required this.count,
    this.onLike,
    this.onShowLikers,
  });

  @override
  Widget build(BuildContext context) {
    const likedColor = Color(0xFFFF4D6D);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InstantHeartButton(
          liked: liked,
          likedColor: likedColor,
          idleColor: const Color(0xFFB0B0B0),
          size: 16,
          onTap: onLike,
        ),
        if (count > 0)
          GestureDetector(
            onTap: onShowLikers,
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: liked ? likedColor : const Color(0xFF8E8E8E),
              ),
            ),
          ),
      ],
    );
  }
}
