import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:halo/Bottom Pages/SettingsPage.dart';
import 'package:halo/chat/chat_screen.dart';
import 'package:halo/chat/chat_service.dart';
import 'package:halo/core/halo_toast.dart';
import 'package:halo/features/auth/presentation/logout.dart';
import 'package:halo/profile_feature/presentation/profile_activity_section.dart';
import 'package:halo/profile_feature/presentation/profile_bio.dart';
import 'package:halo/profile_feature/presentation/profile_buttons.dart';
import 'package:halo/profile_feature/presentation/profile_header.dart';
import 'package:halo/profile_feature/presentation/profile_posts_grid.dart';
import 'package:halo/profile_feature/presentation/profile_providers.dart';
import 'package:halo/profile_feature/presentation/profile_skeleton.dart';
import 'package:halo/profile_feature/presentation/profile_social_links.dart';
import 'package:halo/profile_feature/presentation/profile_stats.dart';
import 'package:halo/profile_feature/presentation/profile_style.dart';
import 'package:halo/profile_feature/presentation/profile_suggestions.dart';

/// Opens the right Edit Profile screen for the account type.
typedef OpenProfileEdit = Future<void> Function(
  BuildContext context, {
  bool focusSocialLinks,
});

/// The profile page every account type shares. One scrolling page; each
/// section is its own sliver and watches only the fields it needs, and data
/// is cached so reopening a profile shows it instantly.
///
/// Order: header · stats · bio · buttons · Suggested for you · Recent
/// Activity · Posts · Social Links · [typeSections].
class ProfileView extends ConsumerStatefulWidget {
  const ProfileView({
    super.key,
    required this.profileUserId,
    required this.onEditProfile,
    this.onBack,
    this.visitorActions = const [],
    this.typeSections = const [],
  });

  final String profileUserId;
  final OpenProfileEdit onEditProfile;

  /// Set when shown as the Profile tab: back goes to Home instead of popping.
  final VoidCallback? onBack;

  /// Extra buttons after Message, only on someone else's profile
  /// (e.g. Book, Review for gurus).
  final List<ProfileAction> visitorActions;

  /// Account-type sections shown at the end of the page (e.g. guru
  /// "Coming Soon" cards).
  /// Each is a box widget; it is wrapped in a sliver here.
  final List<Widget> typeSections;

  @override
  ConsumerState<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends ConsumerState<ProfileView> {
  final _postsKey = GlobalKey();

  /// Posts show a preview until See All is tapped.
  bool _postsExpanded = false;

  String get _id => widget.profileUserId;

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(profileProvider(_id).select(
      (async) => (
        loading: async.isLoading && !async.hasValue,
        failed: async.hasError && !async.hasValue,
        missing: async.hasValue && async.value == null,
      ),
    ));
    final isOwnProfile = ref.watch(myUserIdProvider) == _id;

    final Widget body;
    if (status.loading) {
      body = const ProfileSkeleton();
    } else if (status.failed || status.missing) {
      body = Center(
        child: Text(
          status.failed ? 'Could not load profile' : 'Profile not found',
          style: ProfileStyle.body,
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: ProfileHeader(
                profileUserId: _id,
                isOwnProfile: isOwnProfile,
                onBack: widget.onBack,
                onEditProfile: () => widget.onEditProfile(context),
                onMenu: _onMenu,
              ),
            ),
            SliverToBoxAdapter(
              child: ProfileStats(
                profileUserId: _id,
                onPostsTap: _scrollToPosts,
              ),
            ),
            SliverToBoxAdapter(child: ProfileBio(profileUserId: _id)),
            if (!isOwnProfile)
              SliverToBoxAdapter(
                child: ProfileButtons(
                  profileUserId: _id,
                  onMessage: _openChat,
                  extraActions: widget.visitorActions,
                ),
              ),
            SliverToBoxAdapter(
              child: ProfileSuggestions(profileUserId: _id),
            ),
            SliverToBoxAdapter(
              child: ProfileActivitySection(profileUserId: _id),
            ),
            SliverToBoxAdapter(
              child: ProfilePostsHeader(
                key: _postsKey,
                profileUserId: _id,
                isOwnProfile: isOwnProfile,
                expanded: _postsExpanded,
                onToggle: () =>
                    setState(() => _postsExpanded = !_postsExpanded),
              ),
            ),
            ProfilePostsGrid(
              profileUserId: _id,
              isOwnProfile: isOwnProfile,
              expanded: _postsExpanded,
            ),
            SliverToBoxAdapter(
              child: ProfileSocialLinks(
                profileUserId: _id,
                isOwnProfile: isOwnProfile,
                onAddLinks: () =>
                    widget.onEditProfile(context, focusSocialLinks: true),
              ),
            ),
            for (final section in widget.typeSections)
              SliverToBoxAdapter(child: section),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      );
    }

    return Scaffold(backgroundColor: ProfileStyle.page, body: body);
  }

  Future<void> _refresh() async {
    ref.invalidate(profilePostsProvider(_id));
    ref.invalidate(profileActivityProvider(_id));
    ref.invalidate(profileCountsProvider(_id));
    await Future.wait([
      ref.read(profilePostsProvider(_id).future),
      ref.read(profileActivityProvider(_id).future),
    ]);
  }

  void _scrollToPosts() {
    final ctx = _postsKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _openChat() async {
    final myId = ref.read(myUserIdProvider);
    if (myId == null) {
      HaloToast.show('Please sign in to send messages');
      return;
    }
    try {
      final chatId = await ChatService().getOrCreateChatId(myId, _id);
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ChatScreen(
          chatId: chatId,
          currentUserId: myId,
          otherUserId: _id,
        ),
      ));
    } catch (_) {
      HaloToast.show('Failed to open chat. Please try again.');
    }
  }

  void _onMenu(ProfileMenuAction action) {
    switch (action) {
      case ProfileMenuAction.settings:
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => SettingsPage()));
      case ProfileMenuAction.logout:
        logout(context);
    }
  }
}
