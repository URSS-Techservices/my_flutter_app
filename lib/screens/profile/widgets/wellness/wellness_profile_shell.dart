import 'package:flutter/material.dart';
import 'package:halo/screens/profile/layouts/profile_tab_shell.dart';

export 'package:halo/screens/profile/layouts/profile_tab_shell.dart'
    show ProfileTabShellState;

/// Wellness profile shell — delegates to [ProfileTabShell].
class WellnessProfileShell extends StatefulWidget {
  final bool loading;
  final VoidCallback onBack;
  final Widget cover;
  final List<Widget> appBarActions;
  final Widget header;
  final TabController tabController;
  final List<Tab> tabs;
  final List<Widget> tabViews;

  const WellnessProfileShell({
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
  State<WellnessProfileShell> createState() => WellnessProfileShellState();
}

class WellnessProfileShellState extends State<WellnessProfileShell> {
  final GlobalKey<ProfileTabShellState> _innerKey =
      GlobalKey<ProfileTabShellState>();

  void jumpToTab(int index) => _innerKey.currentState?.jumpToTab(index);

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
      tabs: widget.tabs,
      tabViews: widget.tabViews,
    );
  }
}
