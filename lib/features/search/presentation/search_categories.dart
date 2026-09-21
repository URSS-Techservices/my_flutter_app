import 'package:flutter/material.dart';
import 'package:halo/features/search/presentation/search_responsive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/features/search/domain/search_models.dart';
import 'package:halo/features/search/presentation/search_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
class SearchCategories extends ConsumerWidget {
  final void Function(WellnessCategory category) onCategoryTap;

  const SearchCategories({super.key, required this.onCategoryTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query =
        ref.watch(searchNotifierProvider.select((s) => s.query.trim()));
    final screenWidth = MediaQuery.of(context).size.width;

    // Firestore-managed list; the built-in one shows instantly until it loads
    // (and stays if Firestore has none).
    final categories =
        ref.watch(searchCategoriesProvider).valueOrNull ?? kAllCategories;

    // Filter categories when user is typing
    final filtered = query.isEmpty
        ? categories
        : categories
            .where((c) =>
                c.name.toLowerCase().contains(query.toLowerCase()) ||
                c.subtitle.toLowerCase().contains(query.toLowerCase()) ||
                c.subcategorySpecs.any((s) =>
                    s.displayName.toLowerCase().contains(query.toLowerCase())))
            .toList();

    // Calculate responsive column count & aspect ratio using MediaQuery
    int crossCount = 3;
    if (screenWidth >= 900) {
      crossCount = 4;
    } else if (screenWidth < 350) {
      crossCount = 2; // 2 columns on very small devices for optimal text space
    }

    // Dynamic aspect ratio based on screen width so cards never clip text or images
    final double childAspectRatio =
        (screenWidth < 380) ? 0.72 : (screenWidth < 600 ? 0.78 : 0.88);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              query.isEmpty ? 'Browse by category' : 'Categories',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: (screenWidth * 0.042).clamp(14.0, 18.0),
                color: const Color(0xFF1F1033),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(
                  horizontal: context.s(10), vertical: context.s(4)),
              decoration: BoxDecoration(
                color: kSearchSecondary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(context.s(20)),
              ),
              child: Text(
                '${filtered.length} categories',
                style: GoogleFonts.poppins(
                  color: kSearchSecondary,
                  fontSize: (screenWidth * 0.03).clamp(11.0, 13.0),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: context.s(16)),

        // Grid
        GridView.builder(
          key: ValueKey('cat_grid_${filtered.length}'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filtered.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            crossAxisSpacing: (screenWidth * 0.03).clamp(8.0, 14.0),
            mainAxisSpacing: (screenWidth * 0.03).clamp(8.0, 14.0),
            childAspectRatio: childAspectRatio,
          ),
          itemBuilder: (context, index) => _CategoryCard(
            category: filtered[index],
            onTap: () => onCategoryTap(filtered[index]),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CATEGORY CARD — animated press/hover states
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryCard extends StatefulWidget {
  final WellnessCategory category;
  final VoidCallback onTap;

  const _CategoryCard({required this.category, required this.onTap});

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screenWidth = media.size.width;

    // Responsive dimensions using MediaQuery.of(context)
    final imgSize = (screenWidth * 0.18).clamp(58.0, 78.0);
    final titleFontSize = (screenWidth * 0.031).clamp(11.0, 13.0);

    final isMobile = Theme.of(context).platform == TargetPlatform.android ||
        Theme.of(context).platform == TargetPlatform.iOS;
    final active = isMobile ? _isPressed : (_isHovered || _isPressed);

    final card = AnimatedScale(
      scale: active ? 1.04 : 1.0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: widget.category.backgroundColor,
          borderRadius: BorderRadius.circular(context.s(20)),
          boxShadow: [
            BoxShadow(
              blurRadius: active ? 18 : 8,
              spreadRadius: active ? -2 : -4,
              offset: Offset(0, active ? 10 : 4),
              color: Colors.black.withValues(alpha: active ? 0.12 : 0.06),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(context.s(20)),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(context.s(20)),
              onTap: widget.onTap,
              onTapDown: (_) => setState(() => _isPressed = true),
              onTapCancel: () => setState(() => _isPressed = false),
              onTapUp: (_) => setState(() => _isPressed = false),
              child: Padding(
                padding: EdgeInsets.all((screenWidth * 0.028).clamp(8.0, 12.0)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    // Responsive Category Image
                    if (widget.category.backgroundImage != null)
                      Image.asset(
                        widget.category.backgroundImage!,
                        height: imgSize,
                        width: imgSize,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Text(
                          widget.category.emoji,
                          style: TextStyle(fontSize: imgSize * 0.6),
                        ),
                      )
                    else
                      Text(
                        widget.category.emoji,
                        style: TextStyle(fontSize: imgSize * 0.6),
                      ),
                    SizedBox(height: context.s(4)),

                    // Category Name (no arrow, sitting tight right under the image)
                    Text(
                      widget.category.name,
                      style: GoogleFonts.poppins(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1F1033),
                        height: 1.18,
                      ),
                      maxLines: 3,
                      softWrap: true,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final content = isMobile
        ? card
        : MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            cursor: SystemMouseCursors.click,
            child: card,
          );

    return Semantics(
      button: true,
      label: '${widget.category.name}, ${widget.category.subtitle}',
      child: content,
    );
  }
}
