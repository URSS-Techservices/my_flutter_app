import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:halo/core/halo_toast.dart';
import 'package:halo/profile_feature/domain/social_link.dart';
import 'package:halo/profile_feature/presentation/profile_providers.dart';
import 'package:halo/profile_feature/presentation/profile_section_header.dart';
import 'package:halo/profile_feature/presentation/profile_style.dart';
import 'package:url_launcher/url_launcher.dart';

/// Row of social link cards under the bio. Tapping a card opens the app
/// (or the browser). Hidden for visitors when there are no links; on your
/// own profile an "Add social links" card opens Edit Profile.
class ProfileSocialLinks extends ConsumerWidget {
  const ProfileSocialLinks({
    super.key,
    required this.profileUserId,
    required this.isOwnProfile,
    required this.onAddLinks,
  });

  final String profileUserId;
  final bool isOwnProfile;
  final VoidCallback onAddLinks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(profileProvider(profileUserId).select(
      (async) {
        final p = async.valueOrNull;
        // A string key, so this only rebuilds when the links really change.
        return (
          links: [
            for (final platform in SocialPlatform.values)
              if (p?.socialLinks[platform.key] case final v?)
                '${platform.key}\u0000$v',
          ].join('\u0001'),
          website: p?.website ?? '',
        );
      },
    ));

    final cards = <Widget>[
      if (data.links.isNotEmpty)
        for (final entry in data.links.split('\u0001'))
          _linkCard(entry),
      if (data.website.isNotEmpty)
        _SocialCard(
          icon: const _WebsiteIcon(),
          title: 'Website',
          subtitle: Uri.tryParse(data.website)?.host.replaceFirst('www.', '') ??
              data.website,
          onTap: () => _open(data.website),
        ),
    ];

    if (cards.isEmpty) {
      if (!isOwnProfile) return const SizedBox.shrink();
      cards.add(_SocialCard(
        icon: const Icon(Icons.add_circle_outline,
            color: ProfileStyle.action, size: 30),
        title: 'Add social links',
        subtitle: 'Instagram, YouTube…',
        onTap: onAddLinks,
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfileSectionHeader(
          title: 'Social Links',
          onSeeAll: isOwnProfile && cards.length > 1 ? onAddLinks : null,
          actionLabel: 'Edit Links',
        ),
        SizedBox(
          height: 64,
          child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: ProfileStyle.sideGap),
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => cards[i],
          ),
        ),
      ],
    );
  }

  Widget _linkCard(String entry) {
    final parts = entry.split('\u0000');
    final platform = SocialPlatform.values.firstWhere((p) => p.key == parts[0]);
    final stored = parts[1];
    return _SocialCard(
      icon: SocialPlatformIcon(platform),
      title: platform.label,
      subtitle: platform.display(stored),
      onTap: () => _open(platform.urlFor(stored)),
    );
  }

  static Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    final opened = uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) HaloToast.show('Could not open link');
  }
}

class _SocialCard extends StatelessWidget {
  const _SocialCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Widget icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF9FAFB),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: ProfileStyle.divider),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              icon,
              const SizedBox(width: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 130),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: ProfileStyle.body
                          .copyWith(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    Text(
                      subtitle,
                      style: ProfileStyle.small.copyWith(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WebsiteIcon extends StatelessWidget {
  const _WebsiteIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: ProfileStyle.action,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.link, size: 18, color: Colors.white),
    );
  }
}

/// Round brand-colored badge for a platform (no brand icon package needed).
class SocialPlatformIcon extends StatelessWidget {
  const SocialPlatformIcon(this.platform, {super.key});

  final SocialPlatform platform;

  @override
  Widget build(BuildContext context) {
    final (color, child) = switch (platform) {
      SocialPlatform.instagram => (
          const Color(0xFFE1306C),
          const Icon(Icons.camera_alt_outlined, size: 16, color: Colors.white),
        ),
      SocialPlatform.youtube => (
          const Color(0xFFFF0000),
          const Icon(Icons.play_arrow, size: 18, color: Colors.white),
        ),
      SocialPlatform.spotify => (
          const Color(0xFF1DB954),
          const Icon(Icons.music_note, size: 16, color: Colors.white),
        ),
      SocialPlatform.netflix => (
          Colors.black,
          const Text(
            'N',
            style: TextStyle(
              color: Color(0xFFE50914),
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
        ),
    };
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

