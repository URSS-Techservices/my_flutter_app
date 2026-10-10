import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:halo/core/halo_toast.dart';
import 'package:halo/profile_feature/presentation/guru_booking_page.dart';
import 'package:halo/profile_feature/presentation/profile_buttons.dart';
import 'package:halo/profile_feature/presentation/profile_coming_soon_cards.dart';
import 'package:halo/profile_feature/presentation/profile_edit_page.dart';
import 'package:halo/profile_feature/presentation/profile_providers.dart';
import 'package:halo/profile_feature/presentation/profile_view.dart';

/// Guru profile: the shared [ProfileView] plus a Book button for visitors
/// and the "Coming Soon" cards at the end of the page. A guru viewing their
/// own profile sees no Book (and no Follow / Message), only Edit.
class GuruPage extends ConsumerWidget {
  const GuruPage({super.key, required this.profileUserId, this.onBack});

  final String profileUserId;

  /// Set when shown as the Profile tab: back goes to Home instead of popping.
  final VoidCallback? onBack;

  static const _comingSoon = [
    ProfileComingSoonItem(
      title: 'Popular Products',
      icon: Icons.shopping_bag_outlined,
    ),
    ProfileComingSoonItem(
      title: 'Last Workout',
      svg: 'assets/svg_icons/workout.svg',
    ),
    ProfileComingSoonItem(
      title: 'Reviews & Ratings',
      svg: 'assets/svg_icons/rating.svg',
    ),
    // TODO: switch to the Specialities SVG once it is in assets/svg_icons.
    ProfileComingSoonItem(
      title: 'Specialities',
      icon: Icons.track_changes_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ProfileView(
      profileUserId: profileUserId,
      onBack: onBack,
      onEditProfile: (context, {focusSocialLinks = false}) async {
        final basics = ref.read(profileProvider(profileUserId)).valueOrNull;
        if (basics == null) return;
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ProfileEditPage(
            basics: basics,
            focusSocialLinks: focusSocialLinks,
          ),
        ));
      },
      visitorActions: [
        ProfileAction(
          icon: Icons.calendar_month_outlined,
          label: 'Book',
          onTap: () => _openBooking(context, ref),
        ),
      ],
      typeSections: const [ProfileComingSoonCards(items: _comingSoon)],
    );
  }

  void _openBooking(BuildContext context, WidgetRef ref) {
    if (ref.read(myUserIdProvider) == null) {
      HaloToast.show('Please login to book a session');
      return;
    }
    final name =
        ref.read(profileProvider(profileUserId)).valueOrNull?.name ?? '';
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => GuruBookingPage(guruId: profileUserId, guruName: name),
    ));
  }
}
