import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:halo/Bottom Pages/HomePage.dart'
    hide kPrimaryColor, kSecondaryColor;
import 'package:halo/core/halo_splash.dart';
import 'package:halo/interest_selection_page.dart'
    hide kPrimaryColor, kSecondaryColor, kBackgroundColor;
import 'package:shared_preferences/shared_preferences.dart';

/// Runs after auth + account-type are ready. Decides between the interest
/// selection screen and the main app based on a one-time SharedPreferences
/// flag. Cache is keyed by uid so it invalidates on user change.
class StartupRouter extends StatelessWidget {
  const StartupRouter({super.key});

  static Future<bool>? _cachedInterestsFuture;
  static String? _cachedUserId;

  static Future<bool> _interestsCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('interests_completed') ?? false;
  }

  static void resetCache() {
    _cachedInterestsFuture = null;
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (_cachedUserId != currentUid) {
      _cachedUserId = currentUid;
      _cachedInterestsFuture = null;
    }
    return FutureBuilder<bool>(
      future: _cachedInterestsFuture ??= _interestsCompleted(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const HaloSplash();
        }
        return snapshot.data! ? HomePage() : const InterestSelectionPage();
      },
    );
  }
}
