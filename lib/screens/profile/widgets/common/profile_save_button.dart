import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:halo/screens/profile/profile_theme.dart';
import 'package:halo/services/profile_circle_service.dart';

/// Bookmark a guru or wellness profile into the viewer's My Circle.
class ProfileSaveButton extends StatelessWidget {
  final String? currentUserId;
  final String profileUserId;
  final String accountType;
  final String displayName;
  final String? profilePhoto;
  final String? category;

  const ProfileSaveButton({
    super.key,
    required this.currentUserId,
    required this.profileUserId,
    required this.accountType,
    required this.displayName,
    this.profilePhoto,
    this.category,
  });

  @override
  Widget build(BuildContext context) {
    if (currentUserId == null || currentUserId!.isEmpty || currentUserId == profileUserId) {
      return const SizedBox.shrink();
    }

    final service = ProfileCircleService();
    return StreamBuilder<bool>(
      stream: service.isSavedStream(userId: currentUserId!, profileUserId: profileUserId),
      builder: (context, snapshot) {
        final saved = snapshot.data ?? false;
        return IconButton(
          tooltip: saved ? 'Remove from My Circle' : 'Save to My Circle',
          onPressed: () async {
            try {
              await service.toggleSaved(
                userId: currentUserId!,
                profileUserId: profileUserId,
                accountType: accountType,
                displayName: displayName,
                profilePhoto: profilePhoto,
                category: category,
              );
              Fluttertoast.showToast(
                msg: saved ? 'Removed from My Circle' : 'Saved to My Circle',
              );
            } catch (_) {
              Fluttertoast.showToast(msg: 'Could not update My Circle');
            }
          },
          icon: Icon(
            saved ? Icons.bookmark : Icons.bookmark_border,
            color: ProfileLayout.deepLavender,
          ),
        );
      },
    );
  }
}
