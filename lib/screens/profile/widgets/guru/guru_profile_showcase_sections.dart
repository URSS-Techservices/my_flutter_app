import 'package:flutter/material.dart';
import 'package:halo/screens/profile/widgets/guru/guru_success_stories_section.dart';
import 'package:halo/screens/profile/widgets/guru/guru_video_tutorials_section.dart';

/// Composes guru profile showcase sections (success stories + video tutorials).
class GuruProfileShowcaseSections extends StatelessWidget {
  final bool isOwnProfile;
  final bool successStoriesEnabled;
  final bool videoTutorialsEnabled;
  final List<Map<String, dynamic>> successStories;
  final List<Map<String, dynamic>> videoTutorials;
  final VoidCallback? onAddSuccessStory;
  final void Function(int index, Map<String, dynamic> story)? onEditSuccessStory;
  final void Function(int index)? onDeleteSuccessStory;
  final VoidCallback? onAddVideoTutorial;
  final VoidCallback? onViewAllVideos;
  final void Function(int index, Map<String, dynamic> tutorial)? onEditVideoTutorial;
  final void Function(int index)? onDeleteVideoTutorial;

  const GuruProfileShowcaseSections({
    super.key,
    required this.isOwnProfile,
    required this.successStoriesEnabled,
    required this.videoTutorialsEnabled,
    required this.successStories,
    required this.videoTutorials,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (successStoriesEnabled)
          GuruSuccessStoriesSection(
            stories: successStories,
            isOwnProfile: isOwnProfile,
            onAdd: onAddSuccessStory,
            onEdit: onEditSuccessStory,
            onDelete: onDeleteSuccessStory,
          ),
        if (videoTutorialsEnabled) ...[
          const SizedBox(height: 24),
          GuruVideoTutorialsSection(
            tutorials: videoTutorials,
            isOwnProfile: isOwnProfile,
            onAdd: onAddVideoTutorial,
            onViewAll: onViewAllVideos,
            onEdit: onEditVideoTutorial,
            onDelete: onDeleteVideoTutorial,
          ),
        ],
      ],
    );
  }
}
