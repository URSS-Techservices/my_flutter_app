import 'package:flutter/material.dart';
import 'package:halo/screens/profile/widgets/common/profile_section_title.dart';

class ProfileSectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  final double titleFontSize;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;
  final Color backgroundColor;

  const ProfileSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.titleFontSize = 16,
    this.margin = const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    this.padding = const EdgeInsets.all(12),
    this.backgroundColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProfileSectionTitle(
            title: title,
            trailing: trailing,
            fontSize: titleFontSize,
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
