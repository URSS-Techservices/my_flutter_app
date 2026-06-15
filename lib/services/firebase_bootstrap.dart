import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:halo/config/firebase_web_config.dart';
import 'package:halo/firebase_options.dart';
import 'package:halo/services/app_logger.dart';

/// Initializes Firebase core, Firestore settings, and App Check per platform.
abstract final class FirebaseBootstrap {
  FirebaseBootstrap._();

  static Future<FirebaseApp> initialize() async {
    final app = await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    if (!kIsWeb) {
      // Offline persistence is a mobile/desktop Firestore feature.
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    }

    await _activateAppCheck();
    return app;
  }

  static Future<void> _activateAppCheck() async {
    try {
      if (kIsWeb) {
        if (!FirebaseWebConfig.hasRecaptchaSiteKey) {
          AppLogger.warning(
            LogCategory.general,
            'App Check web skipped: set --dart-define=RECAPTCHA_SITE_KEY=<site_key> '
            'from Firebase Console → App Check → Web',
          );
          return;
        }
        await FirebaseAppCheck.instance.activate(
          webProvider: ReCaptchaV3Provider(FirebaseWebConfig.recaptchaSiteKey),
        );
      } else {
        await FirebaseAppCheck.instance.activate(
          androidProvider: kDebugMode
              ? AndroidProvider.debug
              : AndroidProvider.playIntegrity,
          appleProvider: AppleProvider.debug,
        );
      }
      AppLogger.info(
        LogCategory.general,
        'AppCheck activated platform=${kIsWeb ? 'web' : 'mobile'} debug=$kDebugMode',
      );
    } catch (e) {
      AppLogger.warning(
        LogCategory.general,
        'AppCheck activation failed (non-fatal): $e',
      );
    }
  }
}
