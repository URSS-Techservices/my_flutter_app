import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:halo/core/halo_toast.dart';
import 'package:halo/profile_feature/presentation/profile_providers.dart';
import 'package:halo/profile_feature/presentation/profile_style.dart';

/// Follow and Message buttons shown on someone else's profile.
/// Only this widget rebuilds when follow state changes.
class ProfileButtons extends ConsumerWidget {
  const ProfileButtons({
    super.key,
    required this.profileUserId,
    required this.onMessage,
  });

  final String profileUserId;
  final VoidCallback onMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final follow = ref.watch(followProvider(profileUserId));
    final isFollowing = follow.valueOrNull ?? false;

    Future<void> toggle() async {
      final saved =
          await ref.read(followProvider(profileUserId).notifier).toggle();
      if (!saved) HaloToast.show('Could not update follow. Try again.');
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ProfileStyle.sideGap,
        14,
        ProfileStyle.sideGap,
        8,
      ),
      child: Row(
        children: [
          Expanded(
            child: isFollowing
                ? OutlinedButton.icon(
                    onPressed: follow.isLoading ? null : toggle,
                    icon: const Icon(Icons.how_to_reg_outlined, size: 20),
                    label: Text('Following', style: ProfileStyle.button),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ProfileStyle.text,
                      side: const BorderSide(color: ProfileStyle.divider),
                      minimumSize: const Size.fromHeight(44),
                      shape: _shape,
                    ),
                  )
                : FilledButton.icon(
                    onPressed: follow.isLoading ? null : toggle,
                    icon: const Icon(Icons.person_add_alt_1_outlined, size: 20),
                    label: Text('Follow', style: ProfileStyle.button),
                    style: FilledButton.styleFrom(
                      backgroundColor: ProfileStyle.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(44),
                      shape: _shape,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.icon(
              onPressed: onMessage,
              icon: const Icon(Icons.chat_bubble_outline, size: 20),
              label: Text('Message', style: ProfileStyle.button),
              style: FilledButton.styleFrom(
                backgroundColor: ProfileStyle.primaryLight,
                foregroundColor: ProfileStyle.primaryDark,
                minimumSize: const Size.fromHeight(44),
                shape: _shape,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _shape = RoundedRectangleBorder(
  borderRadius: BorderRadius.all(Radius.circular(12)),
);
