import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/screens/profile/profile_theme.dart';

/// Shared styled [TabBar] for all profile shells.
class ProfileTabBar extends StatelessWidget {
  final TabController controller;
  final List<Tab> tabs;

  const ProfileTabBar({
    super.key,
    required this.controller,
    required this.tabs,
  });

  @override
  Widget build(BuildContext context) {
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
          controller: controller,
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
          tabs: tabs,
        ),
      ),
    );
  }
}
