import 'package:flutter/material.dart';
import 'package:halo/features/search/presentation/search_responsive.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/features/search/domain/search_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SEARCH HERO HEADER
// "Discover Your Wellness Journey" heading on the plain page (no box, no art)
// ─────────────────────────────────────────────────────────────────────────────

class SearchHero extends StatelessWidget {
  const SearchHero({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.s(4)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: GoogleFonts.poppins(
                fontSize: context.sp(26),
                fontWeight: FontWeight.w800,
                height: 1.2,
                letterSpacing: -0.3,
                color: const Color(0xFF1F1033),
              ),
              children: [
                const TextSpan(text: 'Discover Your\n'),
                TextSpan(
                  text: 'Wellness ',
                  style: GoogleFonts.poppins(
                    fontSize: context.sp(26),
                    fontWeight: FontWeight.w800,
                    color: kSearchSecondary,
                  ),
                ),
                const TextSpan(text: 'Journey'),
              ],
            ),
          ),
          SizedBox(height: context.s(10)),
          // Short purple underline
          Container(
            width: context.s(80),
            height: context.s(3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(context.s(4)),
              color: kSearchSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
