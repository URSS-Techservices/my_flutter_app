import 'dart:async';
import 'package:halo/features/search/presentation/search_responsive.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/features/search/domain/search_models.dart';
import 'package:halo/features/search/presentation/search_providers.dart';
import 'package:halo/features/search/presentation/search_state.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SEARCH CAROUSEL
// Firebase-managed banner carousel. Admin uploads images from Firebase console.
// Firestore collection: search_banners
// Fields: imageUrl, title, subtitle, ctaText, ctaRoute, order, isActive
// ─────────────────────────────────────────────────────────────────────────────

// Carousel page state — tracks current page for dot indicators
final _carouselPageProvider =
    StateNotifierProvider<_CarouselPageNotifier, CarouselState>(
        (_) => _CarouselPageNotifier());

class _CarouselPageNotifier extends StateNotifier<CarouselState> {
  _CarouselPageNotifier() : super(const CarouselState());
  void setPage(int page) => state = state.copyWith(currentPage: page);
}

// ─────────────────────────────────────────────────────────────────────────────

class SearchCarousel extends ConsumerStatefulWidget {
  const SearchCarousel({super.key});

  @override
  ConsumerState<SearchCarousel> createState() => _SearchCarouselState();
}

class _SearchCarouselState extends ConsumerState<SearchCarousel> {
  final PageController _pageController = PageController();
  Timer? _autoScrollTimer;

  @override
  void initState() {
    super.initState();
    _startAutoScroll();
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      final banners = ref.read(bannersProvider).valueOrNull ?? [];
      if (banners.length <= 1) return;
      final currentPage = ref.read(_carouselPageProvider).currentPage;
      final nextPage = (currentPage + 1) % banners.length;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final bannersAsync = ref.watch(bannersProvider);
    final currentPage =
        ref.watch(_carouselPageProvider.select((s) => s.currentPage));

    return bannersAsync.when(
      loading: () => _ShimmerBanner(),
      error: (_, __) => const SizedBox.shrink(),
      data: (banners) {
        if (banners.isEmpty) return const SizedBox.shrink();

        return Column(
          children: [
            // Banner PageView
            ClipRRect(
              borderRadius: BorderRadius.circular(context.s(24)),
              child: SizedBox(
                height: context.s(170),
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: banners.length,
                  onPageChanged: (page) =>
                      ref.read(_carouselPageProvider.notifier).setPage(page),
                  itemBuilder: (context, index) =>
                      _BannerCard(banner: banners[index]),
                ),
              ),
            ),

            // Dot indicators
            if (banners.length > 1) ...[
              SizedBox(height: context.s(12)),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  banners.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: EdgeInsets.symmetric(horizontal: context.s(4)),
                    width: i == currentPage ? 20 : 7,
                    height: context.s(7),
                    decoration: BoxDecoration(
                      color: i == currentPage
                          ? kSearchSecondary
                          : kSearchSecondary.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(context.s(4)),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BANNER CARD — single slide
// ─────────────────────────────────────────────────────────────────────────────

class _BannerCard extends StatelessWidget {
  final CarouselBanner banner;
  const _BannerCard({required this.banner});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background image from Firebase Storage
        CachedNetworkImage(
          imageUrl: banner.imageUrl,
          fit: BoxFit.cover,
          placeholder: (_, __) => _ShimmerBanner(),
          errorWidget: (_, __, ___) => Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  kSearchSecondary.withValues(alpha: 0.6),
                  kSearchPrimary.withValues(alpha: 0.4),
                ],
              ),
            ),
          ),
        ),

        // Dark gradient overlay for text readability
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.black.withValues(alpha: 0.58),
                Colors.black.withValues(alpha: 0.20),
              ],
            ),
          ),
        ),

        // Text + CTA overlay
        Padding(
          padding: EdgeInsets.all(context.s(20)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Title
              Text(
                banner.title,
                style: GoogleFonts.poppins(
                  fontSize: context.sp(20),
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.2,
                ),
                maxLines: 2,
              ),
              if (banner.subtitle.isNotEmpty) ...[
                SizedBox(height: context.s(4)),
                Text(
                  banner.subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: context.sp(11),
                    color: Colors.white70,
                  ),
                  maxLines: 2,
                ),
              ],
              SizedBox(height: context.s(14)),

              // CTA button
              GestureDetector(
                onTap: () {
                  // Handle ctaRoute navigation here if needed
                },
                child: Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: context.s(18), vertical: context.s(9)),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [kSearchSecondary, kSearchPrimary],
                    ),
                    borderRadius: BorderRadius.circular(context.s(24)),
                    boxShadow: [
                      BoxShadow(
                        color: kSearchSecondary.withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        banner.ctaText,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: context.sp(13),
                        ),
                      ),
                      SizedBox(width: context.s(4)),
                      Icon(Icons.chevron_right_rounded,
                          color: Colors.white, size: context.s(18)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHIMMER PLACEHOLDER BANNER
// ─────────────────────────────────────────────────────────────────────────────

class _ShimmerBanner extends StatefulWidget {
  @override
  State<_ShimmerBanner> createState() => _ShimmerBannerState();
}

class _ShimmerBannerState extends State<_ShimmerBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 0.9)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(context.s(24)),
          gradient: LinearGradient(
            colors: [
              Colors.grey.shade200.withValues(alpha: _anim.value),
              Colors.grey.shade100.withValues(alpha: _anim.value * 0.7),
              Colors.grey.shade200.withValues(alpha: _anim.value),
            ],
          ),
        ),
      ),
    );
  }
}
