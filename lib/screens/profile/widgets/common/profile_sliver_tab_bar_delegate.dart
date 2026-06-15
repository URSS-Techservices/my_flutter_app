import 'package:flutter/material.dart';

/// Pins a [TabBar] below the flexible space in a nested scroll view.
class ProfileSliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  ProfileSliverTabBarDelegate(this.tabBar);

  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Colors.white,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(ProfileSliverTabBarDelegate oldDelegate) {
    return false;
  }
}
