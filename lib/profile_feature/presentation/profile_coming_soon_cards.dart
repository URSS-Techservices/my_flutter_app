import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:halo/core/halo_toast.dart';
import 'package:halo/profile_feature/presentation/profile_style.dart';

/// One "Coming Soon" feature card. Give either an [svg] path or a
/// fallback [icon]. SVGs keep their own colors; icons use the accent.
class ProfileComingSoonItem {
  const ProfileComingSoonItem({required this.title, this.svg, this.icon})
      : assert(svg != null || icon != null);

  final String title;

  /// Path under `assets/svg_icons/`.
  final String? svg;
  final IconData? icon;
}

/// Row of small "Coming Soon" cards (icon, title, pill, arrow), all four
/// side by side. Tapping one shows a "coming soon" message.
class ProfileComingSoonCards extends StatelessWidget {
  const ProfileComingSoonCards({super.key, required this.items});

  final List<ProfileComingSoonItem> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          ProfileStyle.sideGap, 20, ProfileStyle.sideGap, 0),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(child: _Card(item: items[i])),
            ],
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.item});

  final ProfileComingSoonItem item;

  @override
  Widget build(BuildContext context) {
    final svg = item.svg;
    return Semantics(
      button: true,
      label: '${item.title}, coming soon',
      child: Material(
        color: const Color(0xFFF9FAFB),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: ProfileStyle.divider),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => HaloToast.show('${item.title} is coming soon'),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 6, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: ProfileStyle.page,
                        shape: BoxShape.circle,
                        border: Border.all(color: ProfileStyle.divider),
                      ),
                      child: svg != null
                          ? SvgPicture.asset(
                              svg,
                              width: 18,
                              height: 18,
                            )
                          : Icon(item.icon,
                              size: 18, color: ProfileStyle.action),
                    ),
                    const Spacer(),
                    const Icon(Icons.chevron_right,
                        size: 18, color: ProfileStyle.mutedText),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: ProfileStyle.small.copyWith(
                      fontSize: 12,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                      color: ProfileStyle.text,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: ProfileStyle.surface,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lock_outline,
                            size: 11, color: ProfileStyle.mutedText),
                        const SizedBox(width: 3),
                        Text(
                          'Coming Soon',
                          style: ProfileStyle.small.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: ProfileStyle.mutedText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
