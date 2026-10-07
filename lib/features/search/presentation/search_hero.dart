import 'package:flutter/material.dart';
import 'package:halo/features/search/presentation/search_responsive.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/features/search/domain/search_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SEARCH HERO HEADER
// "Discover Your Wellness Journey" with gradient text + illustration area
// ─────────────────────────────────────────────────────────────────────────────

class SearchHero extends StatelessWidget {
  const SearchHero({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(context.s(28)),
        gradient: const LinearGradient(
          colors: [Color(0xFFEDE5FF), Color(0xFFF8F4FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Purple glow blob top-right
          Positioned(
            top: -20,
            right: -10,
            child: Container(
              width: context.s(150),
              height: context.s(150),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFA58CE3).withValues(alpha: 0.18),
              ),
            ),
          ),

          // Illustration / emoji art top-right
          Positioned(
            top: 0,
            right: 12,
            child: _HeroIllustration(),
          ),

          // Text content
          Padding(
            padding: EdgeInsets.fromLTRB(
                context.s(22), context.s(26), context.s(110), context.s(26)),
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
                // Decorative purple underline
                Container(
                  width: context.s(80),
                  height: context.s(3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(context.s(4)),
                    gradient: const LinearGradient(
                      colors: [kSearchSecondary, kSearchPrimary],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HERO ILLUSTRATION
// Stacked emoji circles mimicking the woman+leaves art from the design
// ─────────────────────────────────────────────────────────────────────────────

class _HeroIllustration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/header.png',
      height: context.s(115),
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => SizedBox(
        width: context.s(100),
        height: context.s(110),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: 8,
              right: 0,
              child: Container(
                width: context.s(90),
                height: context.s(90),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFA58CE3).withValues(alpha: 0.3),
                      const Color(0xFF5B3FA3).withValues(alpha: 0.1),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 16,
              right: 12,
              child: Text('🧘‍♀️', style: TextStyle(fontSize: context.sp(44))),
            ),
          ],
        ),
      ),
    );
  }
}
