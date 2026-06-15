import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class StatsWidget extends StatelessWidget {
  final String label;
  final String value;

  const StatsWidget({
    Key? key,
    required this.label,
    required this.value,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: const Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: const Color(0xFF4A4A5E),
          ),
        ),
      ],
    );
  }
}
