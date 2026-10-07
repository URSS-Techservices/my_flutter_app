import 'package:flutter/material.dart';
import 'package:story_view/story_view.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/story_model.dart';

class UserStoryPager extends StatefulWidget {
  final Map<String, List<StoryModel>> groupedStories;
  final int initialIndex;

  const UserStoryPager({
    super.key,
    required this.groupedStories,
    required this.initialIndex,
  });

  @override
  State<UserStoryPager> createState() => _UserStoryPagerState();
}

class _UserStoryPagerState extends State<UserStoryPager> {
  late final PageController _pageController;
  late final List<String> _userIds;
  final StoryController _storyController = StoryController();

  @override
  void initState() {
    super.initState();

    _userIds = widget.groupedStories.keys.toList();

    _pageController = PageController(
      initialPage: widget.initialIndex,
    );

    _markUserStoriesSeen(widget.initialIndex);
  }

  /// Safely mark all stories of a user as seen
  Future<void> _markUserStoriesSeen(int index) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      debugPrint('User not logged in, skipping story view update');
      return;
    }

    if (index < 0 || index >= _userIds.length) return;

    final uid = user.uid;
    final stories = widget.groupedStories[_userIds[index]];

    if (stories == null || stories.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();

    for (final story in stories) {
      final docRef =
      FirebaseFirestore.instance.collection('stories').doc(story.id);

      batch.update(docRef, {
        'viewers': FieldValue.arrayUnion([uid]),
      });
    }

    try {
      await batch.commit();
    } catch (e) {
      debugPrint('Failed to mark stories as seen: $e');
    }
  }

  @override
  void dispose() {
    _storyController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        itemCount: _userIds.length,
        onPageChanged: (index) async {
          _storyController.play();
          await _markUserStoriesSeen(index);
        },
        itemBuilder: (context, index) {
          final stories = widget.groupedStories[_userIds[index]] ?? [];

          return StoryView(
            storyItems: stories.map((story) {
              if (story.mediaType == 'video') {
                return StoryItem.pageVideo(
                  story.mediaUrl,
                  controller: _storyController,
                );
              } else {
                return StoryItem.pageImage(
                  url: story.mediaUrl,
                  controller: _storyController,
                );
              }
            }).toList(),
            controller: _storyController,
            progressPosition: ProgressPosition.top,
            repeat: false,
            onComplete: () {
              if (_userIds.length > 1 && index < _userIds.length - 1) {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              } else {
                Navigator.pop(context);
              }
            },
          );
        },
      ),
    );
  }
}
