import 'package:flutter/material.dart';
import 'package:halo/screens/profile/widgets/wellness/wellness_amenities_section.dart';
import 'package:halo/screens/profile/widgets/wellness/wellness_awards_section.dart';
import 'package:halo/screens/profile/widgets/wellness/wellness_facility_gallery_section.dart';
import 'package:halo/screens/profile/widgets/wellness/wellness_membership_plans_section.dart';
import 'package:halo/screens/profile/widgets/wellness/wellness_special_offers_section.dart';

/// Composes wellness facility showcase sections (gallery, amenities, plans, offers, awards).
class WellnessProfileFacilitySections extends StatelessWidget {
  final bool isOwnProfile;
  final bool Function(String sectionId) isSectionEnabled;
  final List<Map<String, dynamic>> galleryImages;
  final List<String> amenities;
  final List<Map<String, dynamic>> membershipPlans;
  final List<Map<String, dynamic>> specialOffers;
  final List<Map<String, dynamic>> awards;
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

  const WellnessProfileFacilitySections({
    super.key,
    required this.isOwnProfile,
    required this.isSectionEnabled,
    required this.galleryImages,
    required this.amenities,
    required this.membershipPlans,
    required this.specialOffers,
    required this.awards,
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
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isSectionEnabled('gallery'))
          WellnessFacilityGallerySection(
            images: galleryImages,
            isOwnProfile: isOwnProfile,
            onAdd: onAddGalleryImage,
            onViewAll: onViewFullGallery,
          ),
        if (isSectionEnabled('amenities'))
          WellnessAmenitiesSection(amenities: amenities),
        if (isSectionEnabled('membership'))
          WellnessMembershipPlansSection(
            plans: membershipPlans,
            isOwnProfile: isOwnProfile,
            onAdd: onAddMembershipPlan,
            onEdit: onEditMembershipPlan,
            onDelete: onDeleteMembershipPlan,
            onSubscribe: onSubscribeToPlan,
          ),
        if (isSectionEnabled('offers'))
          WellnessSpecialOffersSection(
            offers: specialOffers,
            isOwnProfile: isOwnProfile,
            onAdd: onAddSpecialOffer,
            onEdit: onEditSpecialOffer,
            onDelete: onDeleteSpecialOffer,
            onViewDetails: onShowOfferDetails,
          ),
        if (isSectionEnabled('awards'))
          WellnessAwardsSection(
            awards: awards,
            isOwnProfile: isOwnProfile,
            onAdd: onAddAward,
          ),
      ],
    );
  }
}
