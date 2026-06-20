import 'dart:async';

import 'package:halo/Bottom Pages/HomePage.dart';
import 'package:halo/Category/categorypage.dart';
import 'package:halo/forgotpasswordpage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:halo/services/blocked_url_memory.dart';
import 'package:halo/services/firebase_bootstrap.dart';
import 'package:halo/services/login_lookup.dart';
import 'package:halo/widgets/google_sign_in_button.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'interest_selection_page.dart';
import 'app_theme_mode.dart';
import 'package:flutter/services.dart';
import 'package:halo/services/app_logger.dart';
import 'package:halo/services/video_memory_bridge.dart';
import 'package:halo/screens/profile/core/profile_deep_link.dart';

// ----------------- HALO THEME CONSTANTS -----------------
const Color kPrimaryColor = Color(0xFFA58CE3); // Lavender
const Color kSecondaryColor = Color(0xFF5B3FA3); // Deep purple
const Color kLightBackground = Color(0xFFF4F1FB); // Soft lavender background
const Color kDarkBackgroundTop = Color(0xFF111111);
const Color kDarkBackgroundBottom = Color(0xFF050505);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppLogger.init();
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
  const _AppRoot({super.key});

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  late final Future<FirebaseApp> _firebaseInit;

  @override
  void initState() {
    super.initState();
    _firebaseInit = FirebaseBootstrap.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FirebaseApp>(
      future: _firebaseInit,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: const _SplashScreen(),
          );
        }
        return MyApp();
      },
    );
  }
}

class MyApp extends StatelessWidget {
  MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseLight = ThemeData.light();
    final baseDark = ThemeData.dark();

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeModeNotifier,
      builder: (context, themeMode, _) => MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: baseLight.copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: kPrimaryColor,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: kLightBackground,
        textTheme: GoogleFonts.poppinsTextTheme(baseLight.textTheme),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          hintStyle: GoogleFonts.poppins(color: Colors.black54),
          labelStyle: GoogleFonts.poppins(color: Colors.black87),
        ),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: kSecondaryColor,
          selectionColor: kPrimaryColor,
          selectionHandleColor: kSecondaryColor,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: kPrimaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            textStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: kSecondaryColor,
            side: const BorderSide(color: kSecondaryColor, width: 1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
      darkTheme: baseDark.copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: kPrimaryColor,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: kDarkBackgroundBottom,
        textTheme: GoogleFonts.poppinsTextTheme(baseDark.textTheme).apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade900,
          hintStyle: GoogleFonts.poppins(color: Colors.white70),
          labelStyle: GoogleFonts.poppins(color: Colors.white),
        ),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: kPrimaryColor,
          selectionColor: kPrimaryColor,
          selectionHandleColor: kPrimaryColor,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: kPrimaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            textStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: BorderSide(color: Colors.white.withOpacity(0.6), width: 1),
            backgroundColor: Colors.white.withOpacity(0.05),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
      home: const AuthGate(), // LogoScreen should later navigate to LoginPage()
      onGenerateRoute: ProfileDeepLinkRoute.onGenerateRoute,
    ),
    );
  }
}
// ===================== SPLASH SCREEN =====================
// Shown while Firebase / SharedPreferences are initialising.
// No timer — it stays until the async work is actually done.

class _SplashScreen extends StatefulWidget {
  const _SplashScreen();
  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _scale = Tween<double>(begin: 0.88, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo image
                Image.asset(
                  'assets/images/Halo.png',
                  height: 120,
                  width: 120,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 20),
                // App name
                Text(
                  'Halo',
                  style: GoogleFonts.pacifico(
                    fontSize: 40,
                    color: kSecondaryColor,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Your wellness community',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.black38,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 48),
                // Subtle loading dots
                _LoadingDots(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Three bouncing dots like WhatsApp / Telegram loading
class _LoadingDots extends StatefulWidget {
  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            // Each dot is offset by 0.2 of the cycle
            final offset = i * 0.25;
            final t = ((_ctrl.value - offset) % 1.0 + 1.0) % 1.0;
            // bounce: up at t=0.3, back at t=0.6
            final dy = t < 0.3
                ? -8.0 * (t / 0.3)
                : t < 0.6
                    ? -8.0 * (1 - (t - 0.3) / 0.3)
                    : 0.0;
            return Transform.translate(
              offset: Offset(0, dy),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: kPrimaryColor.withOpacity(0.7),
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// ===================== AUTH GATE =====================

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show logo splash while Firebase determines auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SplashScreen();
        }

        if (snapshot.hasData) {
          return const StartupRouter();
        }

        return LoginPage();
      },
    );
  }
}

// ===================== STARTUP ROUTER =====================

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
        // Keep showing splash while reading SharedPreferences
        if (!snapshot.hasData) {
          return const _SplashScreen();
        }

        return snapshot.data! ? HomePage() : const InterestSelectionPage();
      },
    );
  }
}

// ----------------- ELEGANT LOGIN PAGE -----------------

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _obscurePassword = true;
  bool _isLoading = false;

  void _showTermsAndConditions() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final dialogTextTheme =
        GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Terms & Conditions',
            style: dialogTextTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          content: SingleChildScrollView(
            child: Text(
              '''By using this application, you agree to the following terms and conditions:

1. Acceptance of Terms
   By accessing and using this app, you accept and agree to be bound by these terms and conditions.

2. User Account
   • You are responsible for maintaining the confidentiality of your account
   • You must provide accurate and complete information
   • You are responsible for all activities under your account

3. User Conduct
   • You agree not to use the app for any unlawful purpose
   • You will not post or transmit any harmful, offensive, or inappropriate content
   • You will respect other users' privacy and rights

4. Intellectual Property
   • All content in this app is protected by copyright and other intellectual property laws
   • You may not reproduce, distribute, or create derivative works without permission

5. Privacy
   • Your use of this app is also governed by our Privacy Policy
   • We collect and use your information as described in our Privacy Policy

6. Limitation of Liability
   • The app is provided "as is" without warranties of any kind
   • We are not liable for any damages arising from your use of the app

7. Changes to Terms
   • We reserve the right to modify these terms at any time
   • Continued use after changes constitutes acceptance

8. Termination
   • We may terminate or suspend your account at any time for violations of these terms

If you have any questions about these Terms & Conditions, please contact us.''',
              style: dialogTextTheme.bodyMedium,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Close',
                style: dialogTextTheme.labelLarge?.copyWith(
                  color: kSecondaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final dialogTextTheme =
        GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Privacy Policy',
            style: dialogTextTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          content: SingleChildScrollView(
            child: Text(
              '''This Privacy Policy describes how we collect, use, and protect your personal information.

1. Information We Collect
   • Account information (username, email, phone number)
   • Profile information (name, bio, photos)
   • Usage data and app activity
   • Device information and location data

2. How We Use Your Information
   • To provide and improve our services
   • To communicate with you
   • To personalize your experience
   • To ensure app security and prevent fraud

3. Information Sharing
   • We do not sell your personal information
   • We may share information with service providers
   • We may disclose information if required by law

4. Data Security
   • We implement security measures to protect your data
   • However, no method of transmission is 100% secure
   • You use the app at your own risk

5. Your Rights
   • You can access and update your personal information
   • You can request deletion of your account
   • You can opt-out of certain communications

6. Cookies and Tracking
   • We use cookies and similar technologies
   • You can manage cookie preferences in your device settings

7. Children's Privacy
   • Our app is not intended for users under 13 years of age
   • We do not knowingly collect information from children

8. Changes to Privacy Policy
   • We may update this policy from time to time
   • We will notify you of significant changes

9. Contact Us
   • If you have questions about this Privacy Policy, please contact us

Last updated: ${DateTime.now().year}''',
              style: dialogTextTheme.bodyMedium,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Close',
                style: dialogTextTheme.labelLarge?.copyWith(
                  color: kSecondaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _signin() async {
  if (!(_formKey.currentState?.validate() ?? false)) return;

  setState(() => _isLoading = true);

  String input = _usernameController.text.trim();
  String password = _passwordController.text.trim();

  try {
    final email = await resolveLoginEmail(input);
    if (email == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not found!')),
      );
      return;
    }

    final userCredential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Update last seen
    await _firestore.collection('users').doc(userCredential.user!.uid).set(
      {'lastSeen': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );

    // Backfill interests from Firestore into SharedPreferences
    try {
      final uid = userCredential.user!.uid;
      final doc = await _firestore.collection('users').doc(uid).get();
      final interests = (doc.data()?['interests'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      if (interests.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('user_interests', interests.cast<String>());
        await prefs.setBool('interests_completed', true);
      }
    } catch (_) {}
    StartupRouter.resetCache();

    // ✅ DO NOTHING HERE — AuthGate stream will automatically
    // detect the login and rebuild with StartupRouter → HomePage
    // No manual Navigator calls needed!

  } on FirebaseAuthException catch (e) {
    if (!mounted) return;
    String msg = 'Login failed';
    if (e.code == 'user-not-found') msg = 'User not found';
    if (e.code == 'wrong-password') msg = 'Incorrect password';
    if (e.code == 'invalid-email') msg = 'Invalid email';
    if (e.code == 'invalid-credential') msg = 'Incorrect email or password';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  } on FirebaseException catch (e) {
    if (!mounted) return;
    final msg = e.code == 'permission-denied'
        ? 'Could not look up account (database access denied). '
            'On web, set RECAPTCHA_SITE_KEY if App Check is enforced.'
        : 'Login failed: ${e.message ?? e.code}';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Login Failed: ${e.toString()}')),
    );
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    final textTheme = GoogleFonts.poppinsTextTheme(
      Theme.of(context).textTheme,
    );

    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: textTheme.labelMedium?.copyWith(
        color: Colors.black87,
        fontWeight: FontWeight.w500,
      ),
      hintStyle: textTheme.bodySmall?.copyWith(
        color: Colors.black54,
      ),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: kPrimaryColor,
          width: 1.5,
        ),
      ),
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.poppinsTextTheme(
      Theme.of(context).textTheme,
    );

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              kDarkBackgroundTop,
              kDarkBackgroundBottom,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 20),

                    // Brand title
                    Text(
                      "Halo.",
                      style: GoogleFonts.pacifico(
                        fontSize: 38,
                        fontWeight: FontWeight.bold,
                        fontStyle: FontStyle.italic,
                        color: kPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Main card
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 24),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.78),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: kPrimaryColor.withOpacity(0.25),
                            blurRadius: 28,
                            spreadRadius: -10,
                            offset: const Offset(0, 18),
                          ),
                        ],
                        border: Border.all(
                          color: Colors.white.withOpacity(0.18),
                          width: 0.9,
                        ),
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            // Username / Email / Phone
                            TextFormField(
                              controller: _usernameController,
                              style: const TextStyle(color: Colors.white),
                              decoration: _inputDecoration(
                                label: "Login ID",
                                hint: "Username / Mobile No. / Email ID",
                                prefixIcon: const Icon(
                                  Icons.person_outline_rounded,
                                  color: Colors.white70,
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your username, mobile or email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Password
                            TextFormField(
                              controller: _passwordController,
                              style: const TextStyle(color: Colors.white),
                              obscureText: _obscurePassword,
                              decoration: _inputDecoration(
                                label: "Password / OTP",
                                hint: "Enter your password or OTP",
                                prefixIcon: const Icon(
                                  Icons.lock_outline_rounded,
                                  color: Colors.white70,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_rounded
                                        : Icons.visibility_rounded,
                                    color: Colors.white70,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a password';
                                }
                                if (value.length < 8) {
                                  return 'Password must be at least 8 characters long';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 18),

                            // Sign in button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _signin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: kPrimaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 13),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                    AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                                    : Text(
                                  "Sign In",
                                  style:
                                  textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Bottom row: create account / forgot password
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              "New here? ",
                              style: textTheme.bodySmall
                                  ?.copyWith(color: Colors.white70),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => CategoryPage()),
                                );
                              },
                              child: Text(
                                "Create account",
                                style: textTheme.bodySmall?.copyWith(
                                  color: kPrimaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ForgotPasswordPage(),
                              ),
                            );
                          },
                          child: Text(
                            "Forgot Password?",
                            style: textTheme.bodySmall?.copyWith(
                              color: kPrimaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Social login
                    Text(
                      "Login with Social",
                      style: textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Column(
                      children: [
                        GoogleSignInButton(onSignedIn: StartupRouter.resetCache),
                        const SizedBox(height: 8),
                        const SocialButton(text: "Login with Facebook"),
                        const SocialButton(text: "Login with Instagram"),
                      ],
                    ),

                    const SizedBox(height: 36),

                    // Footer links
                    Column(
                      children: [
                        GestureDetector(
                          onTap: _showTermsAndConditions,
                          child: Text(
                            "Terms & Conditions",
                            style: textTheme.bodySmall?.copyWith(
                              color: kPrimaryColor,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: _showPrivacyPolicy,
                          child: Text(
                            "Policy",
                            style: textTheme.bodySmall?.copyWith(
                              color: kPrimaryColor,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SocialButton extends StatelessWidget {
  final String text;

  const SocialButton({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.poppinsTextTheme(
      Theme.of(context).textTheme,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.6,
        child: OutlinedButton(
          onPressed: () {},
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            side: BorderSide(color: kPrimaryColor.withOpacity(0.3)),
          ),
          child: Text(
            text,
            style: textTheme.labelLarge?.copyWith(
              color: kSecondaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
