import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:halo/core/halo_toast.dart';
import 'package:halo/profile_feature/presentation/profile_buttons.dart';
import 'package:halo/profile_feature/presentation/profile_coming_soon_cards.dart';
import 'package:halo/profile_feature/presentation/profile_edit_page.dart';
import 'package:halo/profile_feature/presentation/profile_providers.dart';
import 'package:halo/profile_feature/presentation/profile_view.dart';
import 'package:halo/profile_feature/presentation/wellness_booking_page.dart';
import 'package:halo/profile_feature/presentation/wellness_featured_gurus.dart';
import 'package:halo/profile_feature/presentation/wellness_products.dart';
import 'package:halo/profile_feature/presentation/wellness_services_hours.dart';

/// Wellness profile (gym, spa, studio …): the shared [ProfileView] plus a
/// Book button for visitors. Order after the bio: Popular Products ·
/// Specialities (coming soon) · Featured Gurus ·
/// Recent Activity · Posts · Services & Availability · Reviews & Ratings
/// (coming soon) · Social Links. The owner sees Edit instead of buttons.
class WellnessPage extends ConsumerWidget {
  const WellnessPage({super.key, required this.profileUserId, this.onBack});

  final String profileUserId;

  /// Set when shown as the Profile tab: back goes to Home instead of popping.
  final VoidCallback? onBack;

  // Sample categories so the section looks filled until it is built.
  static const _specialityTiles = [
    ProfilePreviewTile('Yoga', Icons.self_improvement_outlined),
    ProfilePreviewTile('Strength', Icons.sports_gymnastics_outlined),
    ProfilePreviewTile('Cardio', Icons.directions_run_outlined),
    ProfilePreviewTile('Recovery', Icons.spa_outlined),
  ];

  static const _reviews = [
    ProfileComingSoonItem(
      title: 'Reviews & Ratings',
      svg: 'assets/svg_icons/rating.svg',
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
            showBusinessSections: true,
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
      showSuggestions: false,
      afterBioSections: [
        WellnessProducts(wellnessId: profileUserId),
        const ProfileComingSoonPreview(
          title: 'Specialities',
          tiles: _specialityTiles,
        ),
      ],
      afterSuggestionsSections: [
        WellnessFeaturedGurus(wellnessId: profileUserId),
      ],
      afterPostsSections: [
        WellnessServicesHours(wellnessId: profileUserId),
        const ProfileComingSoonCards(items: _reviews),
      ],
    );
  }

  void _openBooking(BuildContext context, WidgetRef ref) {
    if (ref.read(myUserIdProvider) == null) {
      HaloToast.show('Please login to book');
      return;
    }
    final name =
        ref.read(profileProvider(profileUserId)).valueOrNull?.name ?? '';
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          WellnessBookingPage(wellnessId: profileUserId, wellnessName: name),
    ));
  }
}
