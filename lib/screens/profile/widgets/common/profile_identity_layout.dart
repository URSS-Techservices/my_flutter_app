import 'package:flutter/material.dart';

/// Shared horizontal layout for identity rows: overlapping avatar + details column.
/// Inner [details] widgets stay type-specific (aspirant / guru / wellness).
class ProfileIdentityLayout extends StatelessWidget {
  final Widget avatar;
  final Widget details;

  const ProfileIdentityLayout({
    super.key,
    required this.avatar,
    required this.details,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Transform.translate(
            offset: const Offset(0, -40),
            child: avatar,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: details,
            ),
          ),
        ],
      ),
    );
  }
}
