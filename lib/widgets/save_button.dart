import 'package:flutter/material.dart';
import 'package:halo/services/save_service.dart';

/// Reusable save/bookmark button. Listens to user's savedPosts in real time.
class SaveButton extends StatelessWidget {
  final String postId;
  final String? currentUserId;
  final Map<String, dynamic>? savedPostsMap;
  final double iconSize;
  final Color? color;

  const SaveButton({
    Key? key,
    required this.postId,
    required this.currentUserId,
    this.savedPostsMap,
    this.iconSize = 26,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (currentUserId == null || currentUserId!.isEmpty) {
      return Icon(
        Icons.bookmark_border,
        size: iconSize,
        color: color ?? Colors.grey,
      );
    }

    if (savedPostsMap != null) {
      final saved = savedPostsMap![postId] == true;
      return IconButton(
        icon: Icon(
          saved ? Icons.bookmark : Icons.bookmark_border,
          size: iconSize,
          color: color ?? Theme.of(context).iconTheme.color,
        ),
        onPressed: () => _onTap(context),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      );
    }

    final saveService = SaveService();
    final stream = saveService.savedPostsStream(currentUserId!);

    return StreamBuilder<Map<String, dynamic>>(
      stream: stream,
      builder: (context, snapshot) {
        final saved = snapshot.data?[postId] == true;
        return IconButton(
          icon: Icon(
            saved ? Icons.bookmark : Icons.bookmark_border,
            size: iconSize,
            color: color ?? Theme.of(context).iconTheme.color,
          ),
          onPressed: () => _onTap(context),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        );
      },
    );
  }

  Future<void> _onTap(BuildContext context) async {
    if (currentUserId == null || currentUserId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to save posts')),
      );
      return;
    }
    try {
      await SaveService().toggleSavePost(
        userId: currentUserId!,
        postId: postId,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update save: $e')),
        );
      }
    }
  }
}
