import 'package:flutter/material.dart';

/// Full-screen centered spinner while profile document loads (legacy behavior).
class ProfileLoadingGate extends StatelessWidget {
  final bool loading;
  final Widget child;

  const ProfileLoadingGate({
    super.key,
    required this.loading,
    required this.child,
  });

  static Widget centeredSpinner() =>
      const Center(child: CircularProgressIndicator());

  @override
  Widget build(BuildContext context) {
    if (loading) return centeredSpinner();
    return child;
  }
}
