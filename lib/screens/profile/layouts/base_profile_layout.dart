import 'package:flutter/material.dart';

/// Composable shell for profile scroll views — optional adoption by legacy pages.
/// Keeps background + scroll physics centralized without forcing one AppBar shape.
class BaseProfileLayout extends StatelessWidget {
  final Color backgroundColor;
  final List<Widget> slivers;
  final Widget? floatingActionButton;

  const BaseProfileLayout({
    super.key,
    required this.backgroundColor,
    required this.slivers,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      floatingActionButton: floatingActionButton,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: slivers,
      ),
    );
  }
}
