import 'package:flutter/material.dart';

/// Renders [child] only when [enabled]; otherwise [fallback] or shrink.
class ProfileSectionGate extends StatelessWidget {
  final bool enabled;
  final Widget child;
  final Widget? fallback;

  const ProfileSectionGate({
    super.key,
    required this.enabled,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return fallback ?? const SizedBox.shrink();
    return child;
  }
}
