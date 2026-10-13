import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:halo/profile_feature/domain/wellness_product.dart';
import 'package:halo/profile_feature/presentation/profile_providers.dart';
import 'package:halo/profile_feature/presentation/profile_section_header.dart';
import 'package:halo/profile_feature/presentation/profile_style.dart';

/// "Popular Products": the centre's products in a row. With none, a
/// friendly card instead of empty space.
class WellnessProducts extends ConsumerWidget {
  const WellnessProducts({super.key, required this.wellnessId});

  final String wellnessId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(wellnessProductsProvider(wellnessId));
    final tile = (MediaQuery.of(context).size.width * 0.34).clamp(116.0, 156.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ProfileSectionHeader(title: 'Popular Products'),
        products.when(
          loading: () => SizedBox(height: tile + 48),
          error: (_, __) => const _EmptyProducts(),
          data: (list) => list.isEmpty
              ? const _EmptyProducts()
              : SizedBox(
                  height: tile + 48,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                        horizontal: ProfileStyle.sideGap),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, i) =>
                        _ProductCard(product: list[i], size: tile),
                  ),
                ),
        ),
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.size});

  final WellnessProduct product;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final placeholder = Container(
      color: ProfileStyle.primaryLight.withValues(alpha: 0.5),
      child: Icon(Icons.shopping_bag_outlined,
          size: size * 0.32, color: ProfileStyle.action),
    );

    return SizedBox(
      width: size,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: size,
              height: size,
              child: product.imageUrl.isEmpty
                  ? placeholder
                  : CachedNetworkImage(
                      imageUrl: product.imageUrl,
                      fit: BoxFit.cover,
                      memCacheWidth: (size * dpr).round(),
                      placeholder: (_, __) =>
                          Container(color: ProfileStyle.surface),
                      errorWidget: (_, __, ___) => placeholder,
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            product.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ProfileStyle.small.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: ProfileStyle.text,
            ),
          ),
          if (product.price.isNotEmpty)
            Text(
              product.price.startsWith('₹')
                  ? product.price
                  : '₹${product.price}',
              maxLines: 1,
              style: ProfileStyle.small.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: ProfileStyle.action,
              ),
            ),
        ],
      ),
    );
  }
}

/// Soft card shown when there are no products yet.
class _EmptyProducts extends StatelessWidget {
  const _EmptyProducts();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: ProfileStyle.sideGap),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ProfileStyle.primaryLight.withValues(alpha: 0.6),
            const Color(0xFFF9FAFB),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ProfileStyle.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: ProfileStyle.page,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.shopping_bag_outlined,
                size: 26, color: ProfileStyle.action),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'No products yet',
              style: ProfileStyle.body.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
