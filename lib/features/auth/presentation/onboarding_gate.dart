import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:halo/core/halo_splash.dart';
import 'package:halo/core/session.dart';
import 'package:halo/features/auth/presentation/choose_account_type_page.dart';
import 'package:halo/features/auth/presentation/session_controller.dart';

/// Routes on [sessionProvider]. Pass existing Login / Home so main.dart stays the owner.
class OnboardingGate extends ConsumerWidget {
  final Widget login;
  final Widget home;

  const OnboardingGate({
    super.key,
    required this.login,
    required this.home,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    return session.when(
      loading: () => const HaloSplash(),
      error: (_, __) => login,
      data: (value) {
        switch (value.status) {
          case SessionStatus.loading:
            return const HaloSplash();
          case SessionStatus.loggedOut:
            return login;
          case SessionStatus.needsAccountType:
            return const ChooseAccountTypePage();
          case SessionStatus.ready:
            return home;
        }
      },
    );
  }
}
