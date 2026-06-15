import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfileEmptyState extends StatelessWidget {
  final String text;
  final bool card;

  const ProfileEmptyState({
    super.key,
    required this.text,
    this.card = false,
  });

  @override
  Widget build(BuildContext context) {
    final child = Center(
      child: Text(text, style: GoogleFonts.poppins()),
    );
    if (!card) return child;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );
  }
}
