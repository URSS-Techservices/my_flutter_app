import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RESPONSIVE HELPERS
// Everything is derived from MediaQuery.of(context). Designs are drawn for a
// 390 px wide phone; sizes scale with the screen but are clamped so they never
// get tiny on small phones or huge on tablets / desktop.
// ─────────────────────────────────────────────────────────────────────────────

const double _kDesignWidth = 390;
const double _kMaxContentWidth = 720;

extension SearchResponsive on BuildContext {
  double get _width => MediaQuery.of(this).size.width;

  /// Width actually used for layout (content is capped on wide screens).
  double get contentWidth => _width.clamp(0.0, _kMaxContentWidth);

  bool get isTablet => _width >= 600;

  /// Scales spacing, padding, radii, icon and box sizes.
  double s(double value) =>
      value * (contentWidth / _kDesignWidth).clamp(0.85, 1.25);

  /// Scales font sizes more gently than layout so text stays readable.
  double sp(double value) =>
      value * (contentWidth / _kDesignWidth).clamp(0.9, 1.15);
}

/// Centers [child] and stops it stretching past a comfortable reading width on
/// tablets, foldables and desktop windows.
class ResponsiveCenter extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth = _kMaxContentWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
