import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/screens/profile/profile_theme.dart';
import 'package:halo/screens/profile/widgets/common/profile_loading_gate.dart';

/// Hybrid Profile + Posts shell — cover app bar, header, tabs below bio, then content.
class AspirantProfileShell extends StatefulWidget {
  final bool loading;
  final VoidCallback onBack;
  final Widget cover;
  final List<Widget> appBarActions;
  final Widget header;
  final Widget profileTab;
  final Widget postsTab;
  final TabController? tabController;

  const AspirantProfileShell({
    super.key,
    required this.loading,
    required this.onBack,
    required this.cover,
    required this.appBarActions,
    required this.header,
    required this.profileTab,
    required this.postsTab,
    this.tabController,
  });

  @override
  State<AspirantProfileShell> createState() => AspirantProfileShellState();
}

class AspirantProfileShellState extends State<AspirantProfileShell>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _ownsController = false;

  TabController get tabController => widget.tabController ?? _tabController;

  void jumpToPostsTab() {
    if (tabController.index != 1) {
      tabController.animateTo(1);
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.tabController != null) {
      _tabController = widget.tabController!;
    } else {
      _tabController = TabController(length: 2, vsync: this);
      _ownsController = true;
    }
  }

  @override
  void dispose() {
    if (_ownsController) _tabController.dispose();
    super.dispose();
  }

  Widget _buildTabBar() {
    return Material(
      color: ProfileLayout.cardBg,
      elevation: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: ProfileLayout.cardBg,
          border: Border(
            top: BorderSide(color: Colors.grey.shade200),
            bottom: BorderSide(color: Colors.grey.shade200),
          ),
        ),
        child: TabBar(
          controller: tabController,
          indicatorColor: ProfileLayout.deepLavender,
          indicatorWeight: 3,
          labelColor: ProfileLayout.deepLavender,
          unselectedLabelColor: ProfileLayout.textSecondary,
          labelStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          tabs: const [
            Tab(text: 'Profile'),
            Tab(text: 'Posts'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              flexibleSpace: FlexibleSpaceBar(
                background: widget.cover,
              ),
            ),
            SliverToBoxAdapter(
              child: ColoredBox(
                color: ProfileLayout.bg,
                child: widget.header,
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _ProfileTabBarHeaderDelegate(
                tabBar: _buildTabBar(),
              ),
            ),
          ];
        },
        body: ColoredBox(
          color: ProfileLayout.bg,
          child: TabBarView(
            controller: tabController,
            children: [
              SingleChildScrollView(
                child: widget.profileTab,
              ),
              widget.postsTab,
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileTabBarHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget tabBar;

  _ProfileTabBarHeaderDelegate({required this.tabBar});

  @override
  double get minExtent => 48;

  @override
  double get maxExtent => 48;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return tabBar;
  }

  @override
  bool shouldRebuild(covariant _ProfileTabBarHeaderDelegate oldDelegate) {
    return oldDelegate.tabBar != tabBar;
  }
}
