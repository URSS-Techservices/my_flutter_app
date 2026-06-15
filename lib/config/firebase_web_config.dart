import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Web-only Firebase / Google OAuth values.
///
/// Override at build time when needed:
///   --dart-define=GOOGLE_WEB_CLIENT_ID=xxx.apps.googleusercontent.com
///   --dart-define=RECAPTCHA_SITE_KEY=your_recaptcha_v3_site_key
abstract final class FirebaseWebConfig {
  FirebaseWebConfig._();

  /// Web OAuth client (client_type 3 from Firebase / Google Cloud Console).
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '61069233213-feutoc7e2j7cdgvt691tkcj743bgddh4.apps.googleusercontent.com',
  );

  /// reCAPTCHA v3 site key from Firebase Console → App Check → Web app.
  static const String recaptchaSiteKey = String.fromEnvironment(
    'RECAPTCHA_SITE_KEY',
    defaultValue: '',
  );

  static bool get hasRecaptchaSiteKey => recaptchaSiteKey.trim().isNotEmpty;

  /// Shared Google Sign-In instance — web needs [clientId]; macOS/iOS use plist.
  static GoogleSignIn createGoogleSignIn() {
    if (kIsWeb) {
      return GoogleSignIn(
        scopes: const ['email'],
        clientId: googleWebClientId,
      );
    }
    return GoogleSignIn(scopes: const ['email']);
  }
}
