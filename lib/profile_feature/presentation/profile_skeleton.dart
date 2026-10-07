import 'package:flutter/material.dart';
import 'package:halo/profile_feature/presentation/profile_style.dart';

/// Grey placeholder shaped exactly like the profile page, shown while the
/// first data loads. Used by every entry point, so opening a profile shows
/// one consistent loading look instead of spinners.
class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  static const _grey = Color(0xFFE5E7EB);

  @override
  Widget build(BuildContext context) {
    Widget bar(double width, double height) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: _grey,
            borderRadius: BorderRadius.circular(6),
          ),
        );

    const avatarTop = ProfileStyle.coverHeight -
        ProfileStyle.cardRadius -
        ProfileStyle.avatarSize / 2;

    return ColoredBox(
      color: ProfileStyle.page,
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          SizedBox(
            height: ProfileStyle.coverHeight + ProfileStyle.avatarSize / 2,
            child: Stack(
              children: [
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: ProfileStyle.coverHeight,
                  child: ColoredBox(color: _grey),
                ),
                Positioned(
                  top: ProfileStyle.coverHeight - ProfileStyle.cardRadius,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: ProfileStyle.page,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(ProfileStyle.cardRadius),
                      ),
                    ),
                    padding: const EdgeInsets.only(
                      left: ProfileStyle.sideGap + ProfileStyle.avatarSize + 12,
                      top: 14,
                    ),
                    alignment: Alignment.topLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        bar(140, 18),
                        const SizedBox(height: 8),
                        bar(90, 12),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: ProfileStyle.sideGap,
                  top: avatarTop,
                  child: Container(
                    width: ProfileStyle.avatarSize,
                    height: ProfileStyle.avatarSize,
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: ProfileStyle.page,
                      shape: BoxShape.circle,
                    ),
                    child: const DecoratedBox(
                      decoration:
                          BoxDecoration(color: _grey, shape: BoxShape.circle),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: ProfileStyle.sideGap,
              vertical: 16,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [bar(56, 34), bar(56, 34), bar(56, 34)],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: ProfileStyle.sideGap),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                bar(double.infinity, 12),
                const SizedBox(height: 8),
                bar(220, 12),
              ],
            ),
          ),
          const SizedBox(height: 24),
          GridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: 3,
            crossAxisSpacing: 3,
            childAspectRatio: 0.8,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 3),
            children: List.generate(6, (_) => const ColoredBox(color: _grey)),
          ),
        ],
      ),
    );
  }
}
