import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/screens/profile/profile_theme.dart';

/// Lavender inline tab chip shared by aspirant discovery tabs and guru filters.
class ProfileInlineTabChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const ProfileInlineTabChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? ProfileLayout.deepLavender : Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected
                    ? ProfileLayout.deepLavender
                    : Colors.grey.shade300,
              ),
            ),
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : ProfileLayout.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
