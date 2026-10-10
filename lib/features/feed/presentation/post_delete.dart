import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:halo/core/halo_toast.dart';
import 'package:halo/features/feed/domain/post_data.dart';
import 'package:halo/features/feed/presentation/feed_data.dart';

/// Instagram-style delete of your own post:
/// iOS confirm dialog → short "Deleting…" spinner → post removed from the
/// feed, profile grid and counts → "Post deleted" toast.
///
/// Returns true when the post was deleted, so the caller can close the
/// viewer. Does nothing for posts that are not the current user's.
Future<bool> confirmAndDeletePost(
  BuildContext context,
  WidgetRef ref,
  PostData post,
) async {
  final uid = ref.read(currentUidProvider);
  if (uid.isEmpty || uid != post.userId) return false;

  final confirmed = await showCupertinoDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => CupertinoAlertDialog(
      title: const Text('Delete post?'),
      content: const Text(
        "This post will be permanently removed from your profile. "
        "You can't undo this.",
      ),
      actions: [
        CupertinoDialogAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete'),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;

  final navigator = Navigator.of(context, rootNavigator: true);
  unawaited(showGeneralDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    barrierColor: Colors.black26,
    transitionDuration: const Duration(milliseconds: 150),
    pageBuilder: (_, __, ___) => const _DeletingHud(),
  ));

  var deleted = false;
  try {
    // Keep the spinner up for a moment even on fast networks, like
    // Instagram, so the delete feels deliberate instead of a flicker.
    await Future.wait([
      ref.read(feedRepositoryProvider).deletePost(userId: uid, postId: post.id),
      Future<void>.delayed(const Duration(milliseconds: 700)),
    ]);
    deleted = true;
  } catch (_) {
    deleted = false;
  }

  navigator.pop(); // close the spinner

  if (!deleted) {
    HaloToast.error('Could not delete post. Please try again.');
    return false;
  }

  ref.read(deletedPostsProvider.notifier).update((s) => {...s, post.id});
  ref.read(feedControllerProvider.notifier).removePost(post.id);
  HapticFeedback.mediumImpact();
  HaloToast.success('Post deleted');
  return true;
}

/// Small frosted iOS-style card with a spinner, shown while deleting.
class _DeletingHud extends StatelessWidget {
  const _DeletingHud();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              width: 128,
              padding: const EdgeInsets.symmetric(vertical: 22),
              color: Colors.white.withValues(alpha: 0.85),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CupertinoActivityIndicator(radius: 13),
                  SizedBox(height: 12),
                  Text(
                    'Deleting…',
                    style: TextStyle(
                      color: Color(0xFF1C1C1E),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// iOS action sheet for your own post (the ••• button): Delete in red,
/// Cancel below. Returns true if the post was deleted.
Future<bool> showOwnPostMenu(
  BuildContext context,
  WidgetRef ref,
  PostData post,
) async {
  final action = await showCupertinoModalPopup<String>(
    context: context,
    builder: (ctx) => CupertinoActionSheet(
      actions: [
        CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(ctx, 'delete'),
          child: const Text('Delete'),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        isDefaultAction: true,
        onPressed: () => Navigator.pop(ctx),
        child: const Text('Cancel'),
      ),
    ),
  );
  if (action != 'delete' || !context.mounted) return false;
  return confirmAndDeletePost(context, ref, post);
}
