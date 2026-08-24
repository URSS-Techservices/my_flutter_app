import 'package:flutter/material.dart';

/// Pins a tab bar widget below the flexible space in a nested scroll view.
class ProfileSliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  ProfileSliverTabBarDelegate(this.tabBar, {this.extent = 48});

  final Widget tabBar;
  final double extent;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return tabBar;
  }

  @override
  bool shouldRebuild(ProfileSliverTabBarDelegate oldDelegate) {
    return oldDelegate.tabBar != tabBar || oldDelegate.extent != extent;
  }
}
