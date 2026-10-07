import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:halo/Bottom Pages/SettingsPage.dart';
import 'package:halo/chat/chat_screen.dart';
import 'package:halo/chat/chat_service.dart';
import 'package:halo/core/halo_toast.dart';
import 'package:halo/features/auth/presentation/logout.dart';
import 'package:halo/profile_feature/presentation/aspirant_activity.dart';
import 'package:halo/profile_feature/presentation/aspirant_edit_page.dart';
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

/// New aspirant profile: one scrolling page. Each section is its own sliver
/// and watches only the fields it needs, so the page is never rebuilt as a
/// whole. Data is cached, so reopening a profile shows it instantly.
class AspirantPage extends ConsumerStatefulWidget {
  const AspirantPage({super.key, required this.profileUserId, this.onBack});

  final String profileUserId;

  /// Set when shown as the Profile tab: back goes to Home instead of popping.
  final VoidCallback? onBack;

  @override
  ConsumerState<AspirantPage> createState() => _AspirantPageState();
}

class _AspirantPageState extends ConsumerState<AspirantPage> {
  final _postsKey = GlobalKey();

  /// Posts show a preview until See All is tapped.
  bool _postsExpanded = false;

  String get _id => widget.profileUserId;

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(aspirantProfileProvider(_id).select(
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
                onEditProfile: () => _editProfile(),
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
                ),
              ),
            SliverToBoxAdapter(
              child: ProfileSuggestions(profileUserId: _id),
            ),
            SliverToBoxAdapter(
              child: AspirantActivity(profileUserId: _id),
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
                onAddLinks: () => _editProfile(focusSocialLinks: true),
              ),
            ),
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

  Future<void> _editProfile({bool focusSocialLinks = false}) async {
    final profile = ref.read(aspirantProfileProvider(_id)).valueOrNull;
    if (profile == null) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AspirantEditPage(
        profile: profile,
        focusSocialLinks: focusSocialLinks,
      ),
    ));
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
