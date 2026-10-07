import 'package:flutter/material.dart';

/// [FlexibleSpaceBar.background] wrapper used by profile [SliverAppBar]s.
class ProfileFlexibleSpaceCoverStack extends StatelessWidget {
  final Widget cover;

  const ProfileFlexibleSpaceCoverStack({
    super.key,
    required this.cover,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [cover],
    );
  }
}
