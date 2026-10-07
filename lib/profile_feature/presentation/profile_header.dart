import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:halo/profile_feature/presentation/profile_photo_viewer.dart';
import 'package:halo/profile_feature/presentation/profile_providers.dart';
import 'package:halo/profile_feature/presentation/profile_style.dart';

enum ProfileMenuAction { settings, logout }

/// Cover, avatar with online dot, name, username, tagline and the
/// Edit Profile button (own profile only). Tapping the photo or cover opens
/// it full screen; changing them happens only in Edit Profile.
class ProfileHeader extends ConsumerWidget {
  const ProfileHeader({
    super.key,
    required this.profileUserId,
    required this.isOwnProfile,
    required this.onEditProfile,
    required this.onMenu,
    this.onBack,
  });

  final String profileUserId;
  final bool isOwnProfile;
  final VoidCallback onEditProfile;
  final ValueChanged<ProfileMenuAction> onMenu;

  /// Used when the profile is a tab (nothing to pop), e.g. go to Home.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final header = ref.watch(aspirantProfileProvider(profileUserId).select(
      (async) {
        final b = async.valueOrNull?.basics;
        return (
          name: b?.name ?? '',
          username: b?.username ?? '',
          tagline: b?.tagline ?? '',
          photo: b?.profilePhoto ?? '',
          cover: b?.coverPhoto ?? '',
        );
      },
    ));

    final status = ref.watch(activityStatusProvider(profileUserId)
        .select((s) => (activeNow: s.activeNow, label: s.label)));
    final navigator = Navigator.of(context);
    final VoidCallback? back =
        onBack ?? (navigator.canPop() ? () => navigator.pop() : null);

    const avatarTop = ProfileStyle.coverHeight -
        ProfileStyle.cardRadius -
        ProfileStyle.avatarSize / 2;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: ProfileStyle.coverHeight,
          child: GestureDetector(
            onTap: () => openPhotoViewer(context, header.cover,
                heroTag: 'cover:$profileUserId'),
            child: _Cover(url: header.cover, heroTag: 'cover:$profileUserId'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(
            top: ProfileStyle.coverHeight - ProfileStyle.cardRadius,
          ),
          child: Container(
            constraints: const BoxConstraints(
              minHeight: ProfileStyle.avatarSize / 2 + 20,
            ),
            decoration: const BoxDecoration(
              color: ProfileStyle.page,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(ProfileStyle.cardRadius),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(
              ProfileStyle.sideGap + ProfileStyle.avatarSize + 12,
              12,
              ProfileStyle.sideGap,
              0,
            ),
            child: _Identity(
              name: header.name,
              username: header.username,
              tagline: header.tagline,
              activeNow: status.activeNow,
              statusLabel: status.label,
              // Edit sits on the tagline row; the name above keeps the
              // full width.
              taglineTrailing:
                  isOwnProfile ? _EditButton(onPressed: onEditProfile) : null,
            ),
          ),
        ),
        Positioned(
          left: ProfileStyle.sideGap,
          top: avatarTop,
          child: GestureDetector(
            onTap: () => openPhotoViewer(context, header.photo,
                heroTag: 'photo:$profileUserId'),
            child: _Avatar(
              url: header.photo,
              online: status.activeNow,
              heroTag: 'photo:$profileUserId',
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  if (back != null)
                    _RoundIconButton(
                      icon: Icons.arrow_back_ios_new,
                      onPressed: back,
                    ),
                  const Spacer(),
                  if (isOwnProfile) _MenuButton(onSelected: onMenu),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.url, required this.heroTag});

  final String url;
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    const fallback = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF475569)],
        ),
      ),
    );
    final width = MediaQuery.sizeOf(context).width;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        if (url.isEmpty)
          fallback
        else
          Hero(
            tag: heroTag,
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              // Decode at screen size, not the original photo size.
              memCacheWidth: (width * dpr).round(),
              placeholder: (_, __) => fallback,
              errorWidget: (_, __, ___) => fallback,
            ),
          ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.url,
    required this.online,
    required this.heroTag,
  });

  final String url;
  final bool online;
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    const size = ProfileStyle.avatarSize;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Container(
            width: size,
            height: size,
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: ProfileStyle.page,
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (url.isEmpty)
                    const ColoredBox(
                      color: ProfileStyle.primaryLight,
                      child: Center(
                        child: Icon(Icons.person,
                            size: 48, color: ProfileStyle.primaryDark),
                      ),
                    )
                  else
                    Hero(
                      tag: heroTag,
                      child: CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        memCacheWidth: (size * dpr).round(),
                        errorWidget: (_, __, ___) =>
                            const Icon(Icons.person, size: 48),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (online)
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: ProfileStyle.online,
                  shape: BoxShape.circle,
                  border: Border.all(color: ProfileStyle.page, width: 3),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Identity extends StatelessWidget {
  const _Identity({
    required this.name,
    required this.username,
    required this.tagline,
    required this.activeNow,
    required this.statusLabel,
    this.taglineTrailing,
  });

  final String name;
  final String username;
  final String tagline;
  final bool activeNow;

  /// "Active now" / "Active 5m ago", or null to show nothing.
  final String? statusLabel;

  /// Shown at the end of the tagline row (Edit on your own profile).
  final Widget? taglineTrailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                name.isEmpty ? 'Halo user' : name,
                style: ProfileStyle.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (username.isNotEmpty)
          Text(
            '@$username',
            style: ProfileStyle.username,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                tagline.isEmpty ? 'Fitness Enthusiast' : tagline,
                style: ProfileStyle.body,
                maxLines: 2,
              ),
            ),
            if (taglineTrailing != null) ...[
              const SizedBox(width: 8),
              taglineTrailing!,
            ],
          ],
        ),
        if (statusLabel != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              children: [
                if (activeNow) ...[
                  const Icon(Icons.circle, size: 8, color: ProfileStyle.online),
                  const SizedBox(width: 4),
                ],
                Text(
                  statusLabel!,
                  style: ProfileStyle.small.copyWith(
                    color: activeNow ? ProfileStyle.online : null,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _EditButton extends StatelessWidget {
  const _EditButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    // Pale sky-blue pill with iOS-blue pencil and text.
    return TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.edit_outlined, size: 15),
      label: Text('Edit', style: ProfileStyle.button.copyWith(fontSize: 13)),
      style: TextButton.styleFrom(
        foregroundColor: ProfileStyle.editBlue,
        backgroundColor: ProfileStyle.editBlueLight,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: const StadiumBorder(),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black38,
      shape: const CircleBorder(),
      child: IconButton(
        icon: Icon(icon, size: 18, color: Colors.white),
        onPressed: onPressed,
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({required this.onSelected});

  final ValueChanged<ProfileMenuAction> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black38,
      shape: const CircleBorder(),
      child: PopupMenuButton<ProfileMenuAction>(
        icon: const Icon(Icons.more_horiz, color: Colors.white),
        onSelected: onSelected,
        itemBuilder: (_) => const [
          PopupMenuItem(
            value: ProfileMenuAction.settings,
            child: Text('Settings'),
          ),
          PopupMenuItem(
            value: ProfileMenuAction.logout,
            child: Text('Logout'),
          ),
        ],
      ),
    );
  }
}
