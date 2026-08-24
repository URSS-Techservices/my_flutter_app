import 'package:flutter/material.dart';
import 'package:halo/features/auth/presentation/login_page.dart';
import 'package:halo/features/auth/presentation/onboarding_gate.dart';
import 'package:halo/features/auth/presentation/startup_router.dart';

/// Top-level auth entry: delegates routing to [OnboardingGate].
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return const OnboardingGate(
      login: LoginPage(),
      home: StartupRouter(),
    );
  }
}
