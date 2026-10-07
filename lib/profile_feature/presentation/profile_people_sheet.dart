import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:halo/profile_feature/domain/profile_person.dart';
import 'package:halo/profile_feature/presentation/profile_providers.dart';
import 'package:halo/profile_feature/presentation/profile_section_header.dart';
import 'package:halo/profile_feature/presentation/profile_style.dart';
import 'package:halo/screens/profile/pages/dynamic_profile_page.dart';

/// Followers / Following in a sheet that slides up over the profile.
/// Swipe down (or tap outside) to close.
void showPeopleSheet(
  BuildContext context, {
  required String userId,
  required bool followers,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 1,
      expand: false,
      builder: (context, scrollController) => _PeopleSheet(
        userId: userId,
        initialTab: followers ? 0 : 1,
        scrollController: scrollController,
      ),
    ),
  );
}

class _PeopleSheet extends StatelessWidget {
  const _PeopleSheet({
    required this.userId,
    required this.initialTab,
    required this.scrollController,
  });

  final String userId;
  final int initialTab;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: ProfileStyle.page,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: DefaultTabController(
        length: 2,
        initialIndex: initialTab,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: ProfileStyle.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            TabBar(
              labelColor: ProfileStyle.text,
              unselectedLabelColor: ProfileStyle.mutedText,
              indicatorColor: ProfileStyle.primaryDark,
              labelStyle: ProfileStyle.button,
              tabs: const [Tab(text: 'Followers'), Tab(text: 'Following')],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _PeopleList(
                    userId: userId,
                    followers: true,
                    scrollController: initialTab == 0 ? scrollController : null,
                  ),
                  _PeopleList(
                    userId: userId,
                    followers: false,
                    scrollController: initialTab == 1 ? scrollController : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeopleList extends ConsumerWidget {
  const _PeopleList({
    required this.userId,
    required this.followers,
    required this.scrollController,
  });

  final String userId;
  final bool followers;

  /// Only the first-shown tab drives the sheet's drag-to-expand.
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (userId: userId, followers: followers);
    final people = ref.watch(profilePeopleProvider(key));

    return people.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(
        child: TextButton(
          onPressed: () => ref.invalidate(profilePeopleProvider(key)),
          child: const Text('Could not load. Tap to retry'),
        ),
      ),
      data: (list) {
        if (list.isEmpty) {
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.only(top: 24),
            children: [
              ProfileEmptyMessage(
                icon: Icons.people_outline,
                text: followers ? 'No followers yet' : 'Not following anyone yet',
              ),
            ],
          );
        }
        return ListView.builder(
          controller: scrollController,
          itemCount: list.length,
          itemBuilder: (context, i) => _PersonTile(person: list[i]),
        );
      },
    );
  }
}

class _PersonTile extends StatelessWidget {
  const _PersonTile({required this.person});

  final ProfilePerson person;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return ListTile(
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: ProfileStyle.primaryLight,
        backgroundImage: person.photoUrl.isEmpty
            ? null
            : CachedNetworkImageProvider(
                person.photoUrl,
                maxWidth: (44 * dpr).round(),
              ),
        child: person.photoUrl.isEmpty
            ? const Icon(Icons.person, color: ProfileStyle.primaryDark)
            : null,
      ),
      title: Text(person.displayName, style: ProfileStyle.body),
      subtitle: person.username.isEmpty
          ? null
          : Text('@${person.username}', style: ProfileStyle.small),
      onTap: () {
        final navigator = Navigator.of(context);
        navigator.pop();
        navigator.push(MaterialPageRoute(
          builder: (_) => DynamicProfilePage(profileUserId: person.id),
        ));
      },
    );
  }
}
