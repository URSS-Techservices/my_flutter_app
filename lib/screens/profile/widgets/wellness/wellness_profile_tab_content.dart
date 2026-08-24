import 'package:flutter/material.dart';
import 'package:halo/screens/profile/widgets/wellness/wellness_check_in_banner.dart';
import 'package:halo/screens/profile/widgets/wellness/wellness_facility_status_section.dart';
import 'package:halo/screens/profile/widgets/wellness/wellness_featured_coaches_section.dart';
import 'package:halo/screens/profile/widgets/wellness/wellness_profile_facility_sections.dart';

/// Composes the wellness profile tab: overview sections + facility showcase.
class WellnessProfileTabContent extends StatelessWidget {
  final bool isOwnProfile;
  final String profileUserId;
  final String wellnessName;
  final String? currentUserId;
  final List<String> featuredGuruIds;
  final bool Function(String sectionId) isSectionEnabled;
  final List<Map<String, dynamic>> galleryImages;
  final List<String> amenities;
  final List<Map<String, dynamic>> membershipPlans;
  final List<Map<String, dynamic>> specialOffers;
  final List<Map<String, dynamic>> awards;
  final Map<String, String> availability;
  final Map<String, dynamic>? facilityHours;
  final Widget popularProducts;
  final Widget featuredStaff;
  final Widget? recentPosts;
  final Widget fitnessEvents;
  final Widget location;
  final Widget servicesAndAvailability;
  final Widget reviews;
  final Widget socialLinks;
  final Widget? visitorBooking;
  final VoidCallback? onAddGalleryImage;
  final VoidCallback? onViewFullGallery;
  final VoidCallback? onAddMembershipPlan;
  final void Function(int index, Map<String, dynamic> plan)? onEditMembershipPlan;
  final void Function(int index)? onDeleteMembershipPlan;
  final void Function(Map<String, dynamic> plan)? onSubscribeToPlan;
  final VoidCallback? onAddSpecialOffer;
  final void Function(int index, Map<String, dynamic> offer)? onEditSpecialOffer;
  final void Function(int index)? onDeleteSpecialOffer;
  final void Function(Map<String, dynamic> offer)? onShowOfferDetails;
  final VoidCallback? onAddAward;
  final VoidCallback? onEditFacilityStatus;
  final VoidCallback? onManageFeaturedCoaches;

  const WellnessProfileTabContent({
    super.key,
    required this.isOwnProfile,
    required this.profileUserId,
    required this.wellnessName,
    this.currentUserId,
    this.featuredGuruIds = const [],
    required this.isSectionEnabled,
    required this.galleryImages,
    required this.amenities,
    required this.membershipPlans,
    required this.specialOffers,
    required this.awards,
    required this.availability,
    required this.popularProducts,
    required this.featuredStaff,
    this.recentPosts,
    required this.fitnessEvents,
    required this.location,
    required this.servicesAndAvailability,
    required this.reviews,
    required this.socialLinks,
    this.visitorBooking,
    this.onAddGalleryImage,
    this.onViewFullGallery,
    this.onAddMembershipPlan,
    this.onEditMembershipPlan,
    this.onDeleteMembershipPlan,
    this.onSubscribeToPlan,
    this.onAddSpecialOffer,
    this.onEditSpecialOffer,
    this.onDeleteSpecialOffer,
    this.onShowOfferDetails,
    this.onAddAward,
    this.onEditFacilityStatus,
    this.facilityHours,
    this.onManageFeaturedCoaches,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        if (!isOwnProfile)
          WellnessCheckInBanner(
            currentUserId: currentUserId,
            wellnessUserId: profileUserId,
            wellnessName: wellnessName,
          ),
        WellnessFeaturedCoachesSection(
          guruIds: featuredGuruIds,
          isOwnProfile: isOwnProfile,
          onManage: onManageFeaturedCoaches,
        ),
        const SizedBox(height: 12),
        popularProducts,
        const SizedBox(height: 24),
        featuredStaff,
        const SizedBox(height: 24),
        if (recentPosts != null) ...[recentPosts!, const SizedBox(height: 24)],
        fitnessEvents,
        const SizedBox(height: 24),
        location,
        const SizedBox(height: 24),
        servicesAndAvailability,
        const SizedBox(height: 24),
        reviews,
        const SizedBox(height: 24),
        socialLinks,
        const SizedBox(height: 24),
        if (visitorBooking != null) ...[visitorBooking!, const SizedBox(height: 24)],
        WellnessProfileFacilitySections(
          isOwnProfile: isOwnProfile,
          isSectionEnabled: isSectionEnabled,
          galleryImages: galleryImages,
          amenities: amenities,
          membershipPlans: membershipPlans,
          specialOffers: specialOffers,
          awards: awards,
          onAddGalleryImage: onAddGalleryImage,
          onViewFullGallery: onViewFullGallery,
          onAddMembershipPlan: onAddMembershipPlan,
          onEditMembershipPlan: onEditMembershipPlan,
          onDeleteMembershipPlan: onDeleteMembershipPlan,
          onSubscribeToPlan: onSubscribeToPlan,
          onAddSpecialOffer: onAddSpecialOffer,
          onEditSpecialOffer: onEditSpecialOffer,
          onDeleteSpecialOffer: onDeleteSpecialOffer,
          onShowOfferDetails: onShowOfferDetails,
          onAddAward: onAddAward,
        ),
        WellnessFacilityStatusSection(
          availability: availability,
          facilityHours: facilityHours,
          isOwnProfile: isOwnProfile,
          onEdit: onEditFacilityStatus,
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}
