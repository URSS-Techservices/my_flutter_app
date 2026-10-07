import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:halo/presence_feature/data/presence_repository.dart';

/// Wrap the app with this once. While the app is open and a user is signed
/// in, it marks them online and refreshes `lastSeen` every 2 minutes; when
/// the app goes to the background it marks them offline.
class PresenceTracker extends StatefulWidget {
  const PresenceTracker({super.key, required this.child});

  final Widget child;

  static const heartbeat = Duration(minutes: 2);

  @override
  State<PresenceTracker> createState() => _PresenceTrackerState();
}

class _PresenceTrackerState extends State<PresenceTracker>
    with WidgetsBindingObserver {
  final _repo = PresenceRepository(FirebaseFirestore.instance);
  StreamSubscription<User?>? _authSub;
  Timer? _timer;
  String? _uid;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      final previous = _uid;
      _uid = user?.uid;
      if (previous != null && previous != _uid) _stop();
      if (_uid != null && _foreground) _start();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (foreground == _foreground) return;
    _foreground = foreground;
    if (foreground) {
      _start();
    } else {
      _goOffline();
    }
  }

  void _start() {
    final uid = _uid;
    if (uid == null) return;
    _write(uid, online: true);
    _timer?.cancel();
    _timer = Timer.periodic(
      PresenceTracker.heartbeat,
      (_) => _write(uid, online: true),
    );
  }

  void _stop() => _timer?.cancel();

  void _goOffline() {
    _stop();
    final uid = _uid;
    if (uid != null) _write(uid, online: false);
  }

  /// Presence is best effort: a failed write must never disturb the app.
  void _write(String uid, {required bool online}) {
    _repo.setOnline(uid, online: online).catchError((_) {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSub?.cancel();
    _goOffline();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
