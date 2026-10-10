import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:halo/profile_feature/presentation/profile_edit_page.dart';
import 'package:halo/profile_feature/presentation/profile_providers.dart';
import 'package:halo/profile_feature/presentation/profile_view.dart';

/// Aspirant profile: the shared [ProfileView]; Edit Profile includes the
/// Fitness Stats section.
class AspirantPage extends ConsumerWidget {
  const AspirantPage({super.key, required this.profileUserId, this.onBack});

  final String profileUserId;

  /// Set when shown as the Profile tab: back goes to Home instead of popping.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ProfileView(
      profileUserId: profileUserId,
      onBack: onBack,
      onEditProfile: (context, {focusSocialLinks = false}) async {
        final aspirant =
            ref.read(aspirantProfileProvider(profileUserId)).valueOrNull ??
                await ref.read(aspirantProfileProvider(profileUserId).future);
        if (aspirant == null || !context.mounted) return;
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ProfileEditPage(
            basics: aspirant.basics,
            fitnessStats: aspirant.fitnessStats,
            focusSocialLinks: focusSocialLinks,
          ),
        ));
      },
    );
  }
}
