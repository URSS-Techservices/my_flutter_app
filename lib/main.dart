import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:halo/app/halo_app.dart';
import 'package:halo/app_theme_mode.dart';
import 'package:halo/core/halo_splash.dart';
import 'package:halo/services/app_logger.dart';
import 'package:halo/services/blocked_url_memory.dart';
import 'package:halo/services/video_memory_bridge.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // initialized the firebase services
  AppLogger.init(); // application login system
  VideoMemoryBridge.install();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  unawaited(loadAppThemeMode());
  unawaited(BlockedUrlMemory.instance.init());
  runApp(const ProviderScope(child: _AppRoot()));
}

class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  late final Future<FirebaseApp> _firebaseInit = _initFirebaseAndAppCheck();

  Future<FirebaseApp> _initFirebaseAndAppCheck() async {
    final app = await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider:
            kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
        appleProvider: AppleProvider.debug,
      );
      AppLogger.info(
        LogCategory.general,
        'AppCheck activated debug=$kDebugMode',
      );
    } catch (e) {
      AppLogger.warning(
        LogCategory.general,
        'AppCheck activation failed (non-fatal): $e',
      );
    }
    return app;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FirebaseApp>(
      future: _firebaseInit,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: HaloSplash(),
          );
        }
        return const HaloApp();
      },
    );
  }
}
