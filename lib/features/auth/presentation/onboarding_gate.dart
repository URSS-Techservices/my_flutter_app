import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:halo/Category/createaspirantaccount.dart';
import 'package:halo/Category/createguruaccount.dart';
import 'package:halo/Category/createwellnessaccount.dart';
import 'package:halo/core/halo_splash.dart';
import 'package:halo/core/session.dart';
import 'package:halo/Category/categorypage.dart';
import 'package:halo/features/auth/presentation/pages/verify_email_page.dart';
import 'package:halo/features/auth/presentation/session_controller.dart';
import 'package:halo/screens/profile/core/profile_type.dart';

/// The single authoritative routing decision for the whole app. Every
/// auth / verification / onboarding branch lives here so no screen has to
/// re-check `user != null`, `emailVerified`, or `profileExists` on its own.
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
          case SessionStatus.emailVerificationRequired:
            return const VerifyEmailPage();
          case SessionStatus.onboardingRequired:
            // No account type yet → 3-category selection. Otherwise resume the
            // profile form for the type they already picked.
            if (value.accountType == null) {
              return const CategoryPage();
            }
            return _profileOnboardingFor(value.accountType!);
          case SessionStatus.authenticated:
            return home;
        }
      },
    );
  }

  Widget _profileOnboardingFor(String accountType) {
    switch (profileKindFromAccountType(accountType)) {
      case ProfileKind.guru:
        return CreateGuruAccount();
      case ProfileKind.wellness:
        return CreateWellnessAccount();
      case ProfileKind.aspirant:
        return CreateAspirantAccount();
    }
  }
}
