import 'package:flutter/material.dart';
import 'package:halo/screens/profile/layouts/profile_tab_shell.dart';

export 'package:halo/screens/profile/layouts/profile_tab_shell.dart'
    show ProfileTabShellState;

/// Aspirant profile shell — delegates to [ProfileTabShell].
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

class AspirantProfileShellState extends State<AspirantProfileShell> {
  final GlobalKey<ProfileTabShellState> _innerKey =
      GlobalKey<ProfileTabShellState>();

  void jumpToPostsTab() => _innerKey.currentState?.jumpToPostsTab();

  @override
  Widget build(BuildContext context) {
    return ProfileTabShell(
      key: _innerKey,
      loading: widget.loading,
      onBack: widget.onBack,
      cover: widget.cover,
      appBarActions: widget.appBarActions,
      header: widget.header,
      tabController: widget.tabController,
      ownsTabController: widget.tabController == null,
      tabs: const [
        Tab(text: 'Profile'),
        Tab(text: 'Posts'),
      ],
      tabViews: [
        widget.profileTab,
        widget.postsTab,
      ],
    );
  }
}
