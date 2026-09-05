import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:halo/features/feed/domain/post_data.dart';
import 'package:halo/features/feed/presentation/feed_data.dart';
import 'package:halo/features/feed/presentation/home_layout.dart';
import 'package:halo/screens/profile/pages/dynamic_profile_page.dart';

void showPostLikers(BuildContext context, String postId) {
  _open(context, title: 'Likes', likers: postLikersProvider(postId));
}

void showCommentLikers(BuildContext context, CommentRef target) {
  _open(context, title: 'Liked by', likers: commentLikersProvider(target));
}

void _open(
  BuildContext context, {
  required String title,
  required ProviderListenable<AsyncValue<List<LikerData>>> likers,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _LikersSheet(title: title, likers: likers),
  );
}

class _LikersSheet extends ConsumerWidget {
  final String title;
  final ProviderListenable<AsyncValue<List<LikerData>>> likers;

  const _LikersSheet({required this.title, required this.likers});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(likers);
    final h = MediaQuery.sizeOf(context).height * 0.62;

    return SizedBox(
      height: h,
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: Color(0xFF262626),
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFDBDBDB)),
          Expanded(
            child: async.when(
              loading: () => const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (_, __) => const Center(child: Text('Could not load likes')),
              data: (list) {
                if (list.isEmpty) {
                  return const Center(
                    child: Text(
                      'No likes yet',
                      style: TextStyle(color: Color(0xFF8E8E8E)),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final person = list[i];
                    return _LikerTile(person: person);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LikerTile extends StatelessWidget {
  final LikerData person;

  const _LikerTile({required this.person});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: person.userId.isEmpty
          ? null
          : () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DynamicProfilePage(profileUserId: person.userId),
                ),
              ),
      child: Row(
        children: [
          FeedAvatar(url: person.photoUrl, radius: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              person.username,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: Color(0xFF262626),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
