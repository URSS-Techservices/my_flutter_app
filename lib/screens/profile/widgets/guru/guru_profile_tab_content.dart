import 'package:flutter/material.dart';
import 'package:halo/screens/profile/profile_theme.dart';
import 'package:halo/screens/profile/widgets/common/profile_section_gate.dart';
import 'package:halo/screens/profile/widgets/guru/guru_profile_showcase_sections.dart';

/// Composes the guru profile tab: programs, activity, reviews, certifications, showcase.
class GuruProfileTabContent extends StatelessWidget {
  final bool isOwnProfile;
  final bool Function(String sectionId) isSectionEnabled;
  final Widget? businessShortcut;
  final Widget popularProducts;
  final Widget lastWorkouts;
  final Widget? recentPosts;
  final Widget specializations;
  final Widget reviews;
  final Widget socialLinks;
  final Widget? certifications;
  final Widget? trainingPrograms;
  final List<Map<String, dynamic>> successStories;
  final List<Map<String, dynamic>> videoTutorials;
  final Widget footer;
  final VoidCallback? onAddSuccessStory;
  final void Function(int index, Map<String, dynamic> story)? onEditSuccessStory;
  final void Function(int index)? onDeleteSuccessStory;
  final VoidCallback? onAddVideoTutorial;
  final VoidCallback? onViewAllVideos;
  final void Function(int index, Map<String, dynamic> tutorial)? onEditVideoTutorial;
  final void Function(int index)? onDeleteVideoTutorial;

  const GuruProfileTabContent({
    super.key,
    required this.isOwnProfile,
    required this.isSectionEnabled,
    this.businessShortcut,
    required this.popularProducts,
    required this.lastWorkouts,
    this.recentPosts,
    required this.specializations,
    required this.reviews,
    required this.socialLinks,
    this.certifications,
    this.trainingPrograms,
    required this.successStories,
    required this.videoTutorials,
    required this.footer,
    this.onAddSuccessStory,
    this.onEditSuccessStory,
    this.onDeleteSuccessStory,
    this.onAddVideoTutorial,
    this.onViewAllVideos,
    this.onEditVideoTutorial,
    this.onDeleteVideoTutorial,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: ProfileLayout.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          if (isOwnProfile && businessShortcut != null) ...[
            const SizedBox(height: 12),
            businessShortcut!,
            const SizedBox(height: 24),
          ],
          if (isSectionEnabled('programs'))
            ProfileSectionGate(
              enabled: true,
              child: Column(
                children: [
                  popularProducts,
                  const SizedBox(height: 24),
                ],
              ),
            ),
          lastWorkouts,
          const SizedBox(height: 24),
          if (recentPosts != null) ...[recentPosts!, const SizedBox(height: 24)],
          specializations,
          const SizedBox(height: 24),
          if (isSectionEnabled('reviews')) ...[reviews, const SizedBox(height: 24)],
          if (isSectionEnabled('social_links')) ...[socialLinks, const SizedBox(height: 24)],
          if (isSectionEnabled('certifications') && certifications != null) certifications!,
          if (isSectionEnabled('programs') && trainingPrograms != null) trainingPrograms!,
          GuruProfileShowcaseSections(
            isOwnProfile: isOwnProfile,
            successStoriesEnabled: isSectionEnabled('success_stories'),
            videoTutorialsEnabled: isSectionEnabled('video_tutorials'),
            successStories: successStories,
            videoTutorials: videoTutorials,
            onAddSuccessStory: onAddSuccessStory,
            onEditSuccessStory: onEditSuccessStory,
            onDeleteSuccessStory: onDeleteSuccessStory,
            onAddVideoTutorial: onAddVideoTutorial,
            onViewAllVideos: onViewAllVideos,
            onEditVideoTutorial: onEditVideoTutorial,
            onDeleteVideoTutorial: onDeleteVideoTutorial,
          ),
          const SizedBox(height: 24),
          footer,
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
