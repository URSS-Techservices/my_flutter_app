import 'package:flutter/material.dart';
import 'package:halo/features/search/presentation/search_responsive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/features/search/domain/search_models.dart';
import 'package:halo/features/search/presentation/search_bar.dart';
import 'package:halo/features/search/presentation/search_carousel.dart';
import 'package:halo/features/search/presentation/search_categories.dart';
import 'package:halo/features/search/presentation/search_hero.dart';
import 'package:halo/features/search/presentation/search_providers.dart';
import 'package:halo/features/search/presentation/search_recents.dart';
import 'package:halo/features/search/presentation/search_results.dart';
import 'package:halo/features/search/presentation/subcategory_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SEARCH PAGE — main entry point
// Thin ConsumerWidget shell. All logic lives in SearchNotifier via providers.
// UI assembled from focused widget files.
// ─────────────────────────────────────────────────────────────────────────────

class SearchPage extends ConsumerWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showRecents =
        ref.watch(searchNotifierProvider.select((s) => s.showRecents));
    final hasQuery =
        ref.watch(searchNotifierProvider.select((s) => s.hasQuery));

    return Scaffold(
      backgroundColor: kSearchBackground,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [kSearchBackground, Color(0xFFEDE8FA)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: GestureDetector(
            // Dismiss keyboard when tapping outside
            onTap: () => FocusScope.of(context).unfocus(),
            behavior: HitTestBehavior.translucent,
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                  horizontal: context.s(20), vertical: context.s(20)),
              child: ResponsiveCenter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── App Bar Row ───────────────────────────────────────────
                    _AppBarRow(),
                    SizedBox(height: context.s(18)),

                    // ── Hero Header ───────────────────────────────────────────
                    const SearchHero(),
                    SizedBox(height: context.s(20)),

                    // ── Search Bar ────────────────────────────────────────────
                    const SearchBarWidget(),
                    SizedBox(height: context.s(16)),

                    // ── Recent Searches (when focused + empty) ────────────────
                    if (showRecents && !hasQuery) ...[
                      const SearchRecents(),
                      SizedBox(height: context.s(20)),
                    ],

                    // ── Search Results (when query has content) ───────────────
                    if (hasQuery) ...[
                      const SearchResults(),
                      SizedBox(height: context.s(20)),
                      Divider(color: Colors.grey.shade200, thickness: 1),
                      SizedBox(height: context.s(16)),
                    ],

                    // ── Category Grid ─────────────────────────────────────────
                    SearchCategories(
                      onCategoryTap: (category) => Navigator.push(
                        context,
                        _slideRoute(SubCategoryPage(category: category)),
                      ),
                    ),
                    SizedBox(height: context.s(28)),

                    // ── Bottom Carousel (Firebase-managed) ────────────────────
                    const SearchCarousel(),
                    SizedBox(height: context.s(24)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// APP BAR ROW — "← Search" + filter icon
// ─────────────────────────────────────────────────────────────────────────────

class _AppBarRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Back button
        Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(context.s(20)),
            onTap: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                Navigator.of(context, rootNavigator: true).maybePop();
              }
            },
            child: Container(
              padding: EdgeInsets.all(context.s(8)),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                color: kSearchSecondary,
                size: context.s(20),
              ),
            ),
          ),
        ),
        SizedBox(width: context.s(12)),
        Text(
          'Search',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: context.sp(18),
            color: const Color(0xFF1F1033),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PAGE TRANSITION HELPER
// ─────────────────────────────────────────────────────────────────────────────

Route _slideRoute(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (_, animation, __) => page,
    transitionsBuilder: (_, animation, __, child) {
      final curved =
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position:
              Tween<Offset>(begin: const Offset(0.06, 0), end: Offset.zero)
                  .animate(curved),
          child: child,
        ),
      );
    },
  );
}
