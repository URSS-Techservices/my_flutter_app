import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:halo/screens/profile/pages/dynamic_profile_page.dart';

/// Resolves `/u/{username}` style deep links to profile pages.
class ProfileDeepLink {
  ProfileDeepLink._();

  static Future<String?> resolveUserIdByUsername(String username) async {
    final trimmed = username.trim();
    if (trimmed.isEmpty) return null;
    final handle = trimmed.startsWith('@') ? trimmed.substring(1) : trimmed;

    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('username', isEqualTo: handle)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return snap.docs.first.id;
  }

  static Future<void> openByUsername(
    BuildContext context, {
    required String username,
  }) async {
    final uid = await resolveUserIdByUsername(username);
    if (uid == null || !context.mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DynamicProfilePage(profileUserId: uid),
      ),
    );
  }
}

/// Route helper for MaterialApp `onGenerateRoute`.
class ProfileDeepLinkRoute {
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final name = settings.name ?? '';
    if (!name.startsWith('/u/')) return null;
    final username = name.substring(3).trim();
    if (username.isEmpty) return null;

    return MaterialPageRoute(
      settings: settings,
      builder: (_) => _ProfileDeepLinkLoader(username: username),
    );
  }
}

class _ProfileDeepLinkLoader extends StatelessWidget {
  final String username;

  const _ProfileDeepLinkLoader({required this.username});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: ProfileDeepLink.resolveUserIdByUsername(username),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final uid = snap.data;
        if (uid == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('User not found')),
          );
        }
        return DynamicProfilePage(profileUserId: uid);
      },
    );
  }
}
