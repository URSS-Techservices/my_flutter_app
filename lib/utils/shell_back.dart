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
