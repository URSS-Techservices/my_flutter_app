import 'package:flutter/material.dart';

/// Back handler for screens embedded in [HomePage]'s bottom-nav [IndexedStack].
/// When [onBackToHome] is set, switches to the Home tab instead of popping the
/// route (which would leave a blank screen).
void popOrGoHome(BuildContext context, {VoidCallback? onBackToHome}) {
  if (onBackToHome != null) {
    onBackToHome();
    return;
  }
  if (Navigator.canPop(context)) {
    Navigator.pop(context);
  }
}

/// Standard in-app page transition (fade + slight slide), used by Search sub-routes
/// and pushed shell pages such as Add Post.
Route<T> buildShellPageRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (_, animation, __) => page,
    transitionsBuilder: (_, animation, __, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.06, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}
