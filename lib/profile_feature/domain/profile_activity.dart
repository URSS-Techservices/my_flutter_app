import 'package:halo/features/feed/domain/post_data.dart';
import 'package:halo/profile_feature/domain/profile_person.dart';

/// One line in Recent Activity: either a new post or a new follow.
class ProfileActivity {
  final DateTime? at;
  final PostData? post;
  final ProfilePerson? followed;

  ProfileActivity.posted(PostData this.post)
      : at = post.createdAt,
        followed = null;

  const ProfileActivity.followed(ProfilePerson this.followed, this.at)
      : post = null;

  /// Newest first; items without a time go last.
  static int newestFirst(ProfileActivity a, ProfileActivity b) {
    if (a.at == null) return 1;
    if (b.at == null) return -1;
    return b.at!.compareTo(a.at!);
  }
}
