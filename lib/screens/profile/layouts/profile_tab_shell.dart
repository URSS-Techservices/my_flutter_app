import 'package:flutter/material.dart';
import 'package:halo/screens/profile/profile_theme.dart';
import 'package:halo/screens/profile/widgets/aspirant/aspirant_posts_tab.dart';
import 'package:halo/screens/profile/widgets/common/profile_loading_gate.dart';
import 'package:halo/screens/profile/widgets/common/profile_sliver_tab_bar_delegate.dart';
import 'package:halo/screens/profile/widgets/common/profile_tab_bar.dart';

/// Unified nested-scroll profile shell used by aspirant, guru, and wellness pages.
class ProfileTabShell extends StatefulWidget {
  final bool loading;
  final VoidCallback onBack;
  final Widget cover;
  final List<Widget> appBarActions;
  final Widget header;
  final TabController? tabController;
  final List<Tab> tabs;
  final List<Widget> tabViews;

  /// When true the shell creates and owns a [TabController] (aspirant default).
  final bool ownsTabController;

  const ProfileTabShell({
    super.key,
    required this.loading,
    required this.onBack,
    required this.cover,
    required this.appBarActions,
    required this.header,
    required this.tabs,
    required this.tabViews,
    this.tabController,
    this.ownsTabController = false,
  }) : assert(ownsTabController || tabController != null);

  @override
  State<ProfileTabShell> createState() => ProfileTabShellState();
}

class ProfileTabShellState extends State<ProfileTabShell>
    with SingleTickerProviderStateMixin {
  TabController? _ownedController;

  TabController get effectiveController =>
      widget.tabController ?? _ownedController!;

  void jumpToTab(int index) {
    if (index >= 0 && index < effectiveController.length) {
      effectiveController.animateTo(index);
    }
  }

  void jumpToPostsTab() => jumpToTab(1);

  @override
  void initState() {
    super.initState();
    if (widget.ownsTabController) {
      _ownedController = TabController(length: widget.tabs.length, vsync: this);
    }
  }

  @override
  void dispose() {
    _ownedController?.dispose();
    super.dispose();
  }

  Widget _wrapTabBody(Widget view) {
    if (view is AspirantPostsTab) return view;
    return SingleChildScrollView(child: view);
  }

  @override
  Widget build(BuildContext context) {
    final tabBar = ProfileTabBar(
      controller: effectiveController,
      tabs: widget.tabs,
    );

    return ProfileLoadingGate(
      loading: widget.loading,
      child: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              pinned: true,
              expandedHeight: ProfileLayout.coverHeight,
              backgroundColor: ProfileLayout.deepLavender,
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.white),
              actionsIconTheme: const IconThemeData(color: Colors.white),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: widget.onBack,
              ),
              actions: widget.appBarActions,
              flexibleSpace: FlexibleSpaceBar(background: widget.cover),
            ),
            SliverToBoxAdapter(
              child: ColoredBox(
                color: ProfileLayout.bg,
                child: widget.header,
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: ProfileSliverTabBarDelegate(tabBar),
            ),
          ];
        },
        body: ColoredBox(
          color: ProfileLayout.bg,
          child: TabBarView(
            controller: effectiveController,
            physics: const BouncingScrollPhysics(),
            children: widget.tabViews.map(_wrapTabBody).toList(),
          ),
        ),
      ),
    );
  }
}
