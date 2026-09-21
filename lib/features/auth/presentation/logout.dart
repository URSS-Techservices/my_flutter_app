import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:halo/core/halo_toast.dart';
import 'package:halo/features/auth/presentation/session_controller.dart';

/// The single logout entry point for every screen.
///
/// Signs out through [authActionProvider] (Firebase + Google), which flips the
/// session to logged-out so [OnboardingGate] shows the login page. Screens must
/// not navigate to the login page themselves; we only pop any routes that were
/// pushed on top of the gate (profile, settings, ...) so login is revealed.
Future<void> logout(BuildContext context) async {
  final auth = ProviderScope.containerOf(context, listen: false)
      .read(authActionProvider.notifier);
  final navigator = Navigator.of(context, rootNavigator: true);

  if (!await auth.signOut()) {
    HaloToast.show('Logout failed');
    return;
  }
  navigator.popUntil((route) => route.isFirst);
}
