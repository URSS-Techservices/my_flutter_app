import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:halo/services/follow_service.dart';

/// Centralized follow / unfollow flow for profile [State] classes.
///
/// Preserves the existing pattern: optimistic [setState], optional follow-button
/// animation, Firestore via [FollowService], rollback + toast on failure.
abstract final class ProfileFollowToggle {
  ProfileFollowToggle._();

  /// Optimistic UI is applied in [applyOptimisticUi] (typically a `setState`).
  /// [afterOptimisticUi] runs immediately after (e.g. follow icon animation) — omit for no animation.
  static Future<void> runOptimisticToggle({
    required FollowService followService,
    required String currentUserId,
    required String profileUserId,
    required bool wasFollowing,
    required VoidCallback applyOptimisticUi,
    required VoidCallback rollbackUi,
    VoidCallback? afterOptimisticUi,
    String errorToast = 'Something went wrong. Please try again.',
    bool debugLogOnError = true,
  }) async {
    applyOptimisticUi();
    afterOptimisticUi?.call();
    try {
      await followService.setFollowState(
        currentUserId: currentUserId,
        profileUserId: profileUserId,
        shouldFollow: !wasFollowing,
      );
    } catch (e) {
      if (debugLogOnError) {
        debugPrint('follow toggle error: $e');
      }
      rollbackUi();
      Fluttertoast.showToast(msg: errorToast);
    }
  }
}
