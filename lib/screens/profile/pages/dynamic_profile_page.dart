import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:halo/controllers/profile_controller.dart';
import 'package:halo/Profile Pages/aspirant_profile_page.dart' as aspirant_legacy;
import 'package:halo/Profile Pages/guru_profile_page.dart' as guru_legacy;
import 'package:halo/Profile Pages/wellness_profile_page.dart' as wellness_legacy;
import 'package:halo/screens/profile/widgets/profile_skeleton.dart';

/// Routes to the correct legacy profile implementation based on `accountType`.
/// UI and behavior are unchanged — this is the modular entry point for navigation.
class DynamicProfilePage extends ConsumerWidget {
  final String profileUserId;

  const DynamicProfilePage({super.key, required this.profileUserId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileStreamProvider(profileUserId));
    return profileAsync.when(
      loading: () => const ProfileSkeleton(),
      error: (_, __) =>
          aspirant_legacy.ProfilePage(profileUserId: profileUserId),
      data: (user) {
        final type =
            (user?.accountType ?? 'aspirant').toString().toLowerCase();
        if (type == 'guru') {
          return guru_legacy.GuruProfilePage(profileUserId: profileUserId);
        }
        if (type == 'wellness') {
          return wellness_legacy.WellnessProfilePage(
            profileUserId: profileUserId,
          );
        }
        return aspirant_legacy.ProfilePage(profileUserId: profileUserId);
      },
    );
  }
}
