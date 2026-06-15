import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfileSectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final double fontSize;

  const ProfileSectionTitle({
    super.key,
    required this.title,
    this.trailing,
    this.fontSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: fontSize,
            color: Colors.black87,
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
