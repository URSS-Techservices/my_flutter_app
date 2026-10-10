import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:halo/core/halo_toast.dart';
import 'package:halo/profile_feature/presentation/profile_providers.dart';
import 'package:halo/profile_feature/presentation/profile_style.dart';

/// An extra button after Message, e.g. Book or Review on a guru profile.
class ProfileAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const ProfileAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

/// Follow, Message and any [extraActions], shown on someone else's profile.
/// Only this widget rebuilds when follow state changes. Every button keeps
/// its label; on narrow screens the icons are dropped first.
class ProfileButtons extends ConsumerWidget {
  const ProfileButtons({
    super.key,
    required this.profileUserId,
    required this.onMessage,
    this.extraActions = const [],
  });

  final String profileUserId;
  final VoidCallback onMessage;
  final List<ProfileAction> extraActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final follow = ref.watch(followProvider(profileUserId));
    final isFollowing = follow.valueOrNull ?? false;

    Future<void> toggle() async {
      final saved =
          await ref.read(followProvider(profileUserId).notifier).toggle();
      if (!saved) HaloToast.show('Could not update follow. Try again.');
    }

    final secondary = [
      ProfileAction(
        icon: Icons.chat_bubble_outline,
        label: 'Message',
        onTap: onMessage,
      ),
      ...extraActions,
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ProfileStyle.sideGap,
        14,
        ProfileStyle.sideGap,
        8,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = 8.0;
          final buttons = 1 + secondary.length;
          final each = (constraints.maxWidth - gap * (buttons - 1)) / buttons;
          // Labels always show; icons drop first when space is tight.
          final showIcons = each >= 112;

          return Row(
            children: [
              Expanded(
                child: _ProfileButton(
                  label: isFollowing ? 'Following' : 'Follow',
                  icon: isFollowing
                      ? Icons.how_to_reg_outlined
                      : Icons.person_add_alt_1_outlined,
                  showIcon: showIcons,
                  onTap: follow.isLoading ? null : toggle,
                  background:
                      isFollowing ? ProfileStyle.surface : ProfileStyle.action,
                  foreground: isFollowing ? ProfileStyle.text : Colors.white,
                ),
              ),
              for (final action in secondary) ...[
                const SizedBox(width: gap),
                Expanded(
                  child: _ProfileButton(
                    label: action.label,
                    icon: action.icon,
                    showIcon: showIcons,
                    onTap: action.onTap,
                    background: ProfileStyle.surface,
                    foreground: ProfileStyle.action,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Rounded button whose label shrinks to fit instead of overflowing on
/// narrow screens or with large system text.
class _ProfileButton extends StatelessWidget {
  const _ProfileButton({
    required this.label,
    required this.icon,
    required this.showIcon,
    required this.onTap,
    required this.background,
    required this.foreground,
  });

  final String label;
  final IconData icon;
  final bool showIcon;
  final VoidCallback? onTap;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        disabledBackgroundColor: background,
        disabledForegroundColor: foreground,
        minimumSize: const Size.fromHeight(44),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showIcon) ...[
              Icon(icon, size: 19),
              const SizedBox(width: 6),
            ],
            Text(label, style: ProfileStyle.button, maxLines: 1),
          ],
        ),
      ),
    );
  }
}
