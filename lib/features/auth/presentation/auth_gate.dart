import 'package:flutter/material.dart';
import 'package:halo/Bottom Pages/HomePage.dart'
    hide kPrimaryColor, kSecondaryColor;
import 'package:halo/features/auth/presentation/pages/login_page.dart';
import 'package:halo/features/auth/presentation/onboarding_gate.dart';

/// Top-level auth entry: delegates routing to [OnboardingGate]. Home is shown
/// directly once onboarding is complete — interest selection is now an optional
/// step reachable from Settings, not a gate in front of Home.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return OnboardingGate(
      login: const LoginPage(),
      home: HomePage(),
    );
  }
}
