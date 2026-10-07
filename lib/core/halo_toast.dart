import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:halo/core/halo_theme.dart';

enum HaloToastKind { auto, info, success, error }

/// iOS-style floating banner. Use [HaloToast.show] instead of SnackBar.
class HaloToast {
  HaloToast._();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static OverlayEntry? _entry;

  static void show(
    String message, {
    HaloToastKind kind = HaloToastKind.auto,
    Duration duration = const Duration(seconds: 3),
  }) {
    final overlay = navigatorKey.currentState?.overlay;
    if (overlay == null || message.trim().isEmpty) return;

    _entry?.remove();
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
    duration: const Duration(milliseconds: 280),
    reverseDuration: const Duration(milliseconds: 200),
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );
  late final Animation<double> _scale = Tween<double>(begin: 0.94, end: 1).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
  );

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
        return kPrimaryColor;
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
    final maxWidth = MediaQuery.sizeOf(context).width - 48;
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: false,
        child: Align(
          alignment: Alignment.center,
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: GestureDetector(
                onTap: _dismiss,
                child: SizedBox(
                  width: maxWidth.clamp(0, 420),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.88),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.14),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
                          child: Row(
                            children: [
                              Icon(_icon, color: _accent, size: 22),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  widget.message,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFF1C1C1E),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    height: 1.25,
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
      ),
    );
  }
}
