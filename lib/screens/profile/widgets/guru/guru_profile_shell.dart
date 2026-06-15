import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/screens/profile/profile_theme.dart';
import 'package:halo/screens/profile/widgets/aspirant/aspirant_posts_tab.dart';
import 'package:halo/screens/profile/widgets/common/profile_loading_gate.dart';

/// Guru profile shell — cover, header, tabs below bio, tab content.
class GuruProfileShell extends StatefulWidget {
  final bool loading;
  final VoidCallback onBack;
  final Widget cover;
  final List<Widget> appBarActions;
  final Widget header;
  final TabController tabController;
  final List<Tab> tabs;
  final List<Widget> tabViews;

  const GuruProfileShell({
    super.key,
    required this.loading,
    required this.onBack,
    required this.cover,
    required this.appBarActions,
    required this.header,
    required this.tabController,
    required this.tabs,
    required this.tabViews,
  });

  @override
  State<GuruProfileShell> createState() => GuruProfileShellState();
}

class GuruProfileShellState extends State<GuruProfileShell> {
  void jumpToTab(int index) {
    if (index >= 0 && index < widget.tabController.length) {
      widget.tabController.animateTo(index);
    }
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
          controller: widget.tabController,
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
          tabs: widget.tabs,
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
              delegate: _GuruTabBarHeaderDelegate(tabBar: _buildTabBar()),
            ),
          ];
        },
        body: ColoredBox(
          color: ProfileLayout.bg,
          child: TabBarView(
            controller: widget.tabController,
            physics: const BouncingScrollPhysics(),
            children: [
              SingleChildScrollView(child: widget.tabViews[0]),
              widget.tabViews[1] is AspirantPostsTab
                  ? widget.tabViews[1]
                  : SingleChildScrollView(child: widget.tabViews[1]),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuruTabBarHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget tabBar;

  _GuruTabBarHeaderDelegate({required this.tabBar});

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
  bool shouldRebuild(covariant _GuruTabBarHeaderDelegate oldDelegate) {
    return oldDelegate.tabBar != tabBar;
  }
}
