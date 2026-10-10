import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum HaloToastKind { auto, info, success, error }

/// iOS-style notice: a small frosted capsule that slides down from the top,
/// like the system "Copied" / AirDrop banners. It never covers the screen,
/// replaces any notice already showing, and can be swiped up or tapped
/// away. Use [HaloToast.show] instead of SnackBar.
class HaloToast {
  HaloToast._();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static OverlayEntry? _entry;

  static void show(
    String message, {
    HaloToastKind kind = HaloToastKind.auto,
    Duration duration = const Duration(milliseconds: 2200),
  }) {
    final overlay = navigatorKey.currentState?.overlay;
    if (overlay == null || message.trim().isEmpty) return;

    _entry?.remove();
    HapticFeedback.lightImpact();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _HaloToastBanner(
        message: message.trim(),
        kind: kind == HaloToastKind.auto ? _inferKind(message) : kind,
        duration: duration,
        onDone: () {
          entry.remove();
          if (identical(_entry, entry)) _entry = null;
        },
      ),
    );
    _entry = entry;
    overlay.insert(entry);
  }

  static void success(String message) =>
      show(message, kind: HaloToastKind.success);

  static void error(String message) =>
      show(message, kind: HaloToastKind.error);

  static HaloToastKind _inferKind(String message) {
    final m = message.toLowerCase();
    if (RegExp(
      r'fail|error|invalid|could not|please enter|please select|please sign|please login|please accept|must |wrong|denied|required|already taken|already exists|no document|no image',
    ).hasMatch(m)) {
      return HaloToastKind.error;
    }
    if (RegExp(
      r'success|updated|saved|sent|added|deleted|created|uploaded|unblocked',
    ).hasMatch(m)) {
      return HaloToastKind.success;
    }
    return HaloToastKind.info;
  }
}

class _HaloToastBanner extends StatefulWidget {
  const _HaloToastBanner({
    required this.message,
    required this.kind,
    required this.duration,
    required this.onDone,
  });

  final String message;
  final HaloToastKind kind;
  final Duration duration;
  final VoidCallback onDone;

  @override
  State<_HaloToastBanner> createState() => _HaloToastBannerState();
}

class _HaloToastBannerState extends State<_HaloToastBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
    reverseDuration: const Duration(milliseconds: 220),
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, -1.2),
    end: Offset.zero,
  ).animate(CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutBack,
    reverseCurve: Curves.easeIn,
  ));

  @override
  void initState() {
    super.initState();
    _controller.forward();
    Future<void>.delayed(widget.duration, _dismiss);
  }

  Future<void> _dismiss() async {
    if (!mounted) return;
    await _controller.reverse();
    if (mounted) widget.onDone();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _accent {
    switch (widget.kind) {
      case HaloToastKind.success:
        return const Color(0xFF34C759);
      case HaloToastKind.error:
        return const Color(0xFFFF3B30);
      case HaloToastKind.info:
      case HaloToastKind.auto:
        return const Color(0xFF8E8E93);
    }
  }

  IconData get _icon {
    switch (widget.kind) {
      case HaloToastKind.success:
        return CupertinoIcons.check_mark_circled_solid;
      case HaloToastKind.error:
        return CupertinoIcons.exclamationmark_circle_fill;
      case HaloToastKind.info:
      case HaloToastKind.auto:
        return CupertinoIcons.info_circle_fill;
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Positioned(
      top: media.padding.top + 8,
      left: 16,
      right: 16,
      child: Center(
        child: SlideTransition(
          position: _slide,
          child: FadeTransition(
            opacity: _fade,
            child: GestureDetector(
              onTap: _dismiss,
              onVerticalDragEnd: (d) {
                if ((d.primaryVelocity ?? 0) < 0) _dismiss();
              },
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(100),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.10),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(100),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(14, 10, 18, 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.82),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                            color: Colors.black.withValues(alpha: 0.05),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_icon, color: _accent, size: 18),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                widget.message,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF1C1C1E),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  height: 1.25,
                                  letterSpacing: -0.2,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
