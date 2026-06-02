import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../widgets/google_sign_in_button.dart';
import '../signuppage.dart';
import '../forgotpasswordpage.dart';

// THEME CONSTANTS FOR THIS PAGE
const Color kPrimaryColor = Color(0xFFA58CE3); // Lavender
const Color kSecondaryColor = Color(0xFF5B3FA3); // Deep Purple
const Color kBackgroundColor = Color(0xFFF4F1FB); // Light lavender-gray

class LoginPage extends StatefulWidget {
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _loginIdController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  // 👇 Hover / interaction states
  bool _isCardHovered = false;
  bool _isSignInHovered = false;
  bool _isGoogleHovered = false;
  bool _isSignupHovered = false;
  bool _isForgotHovered = false;

  @override
  void dispose() {
    _loginIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final input = _loginIdController.text.trim();
    final password = _passwordController.text.trim();

    if (input.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter login ID and password')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String emailToUse;

      if (input.contains('@')) {
        // User typed an email directly
        emailToUse = input;
      } else {
        // User typed username or phone
        final lower = input.toLowerCase();
        QuerySnapshot snap;

        // 1) Try username
        snap = await FirebaseFirestore.instance
            .collection('users')
            .where('username_lower', isEqualTo: lower)
            .limit(1)
            .get();

        // 2) If not found, try phone
        if (snap.docs.isEmpty) {
          snap = await FirebaseFirestore.instance
              .collection('users')
              .where('phone', isEqualTo: input)
              .limit(1)
              .get();
        }

        if (snap.docs.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User not found')),
          );
          setState(() => _isLoading = false);
          return;
        }

        final data = snap.docs.first.data() as Map<String, dynamic>;
        final email = data['email'] as String?;

        if (email == null || email.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('This account does not have an email set.')),
          );
          setState(() => _isLoading = false);
          return;
        }

        emailToUse = email;
      }

      // Sign in with FirebaseAuth
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailToUse,
        password: password,
      );

      // TODO: Navigate to your home screen
      // Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomePage()));
    } on FirebaseAuthException catch (e) {
      String msg = 'Login failed';
      if (e.code == 'user-not-found') msg = 'User not found';
      if (e.code == 'wrong-password') msg = 'Incorrect password';
      if (e.code == 'invalid-email') msg = 'Invalid email';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  InputDecoration _inputDecoration({
    required String hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    final textTheme = GoogleFonts.poppinsTextTheme(
      Theme.of(context).textTheme,
    );

    return InputDecoration(
      hintText: hintText,
      hintStyle: textTheme.bodyMedium?.copyWith(
        color: Colors.black54,
      ),
      filled: true,
      fillColor: const Color(0xFFF9F6FF),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: kPrimaryColor,
          width: 1.4,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.poppinsTextTheme(
      Theme.of(context).textTheme,
    );

    return Theme(
      data: Theme.of(context).copyWith(textTheme: textTheme),
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFF5EDFF),
                Color(0xFFE8E4FF),
                kBackgroundColor,
              ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: MouseRegion(
                    onEnter: (_) =>
                        setState(() => _isCardHovered = true),
                    onExit: (_) =>
                        setState(() => _isCardHovered = false),
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 150),
                      curve: Curves.easeOut,
                      scale: _isCardHovered ? 1.01 : 1.0,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 28),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.96),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              blurRadius: _isCardHovered ? 45 : 32,
                              spreadRadius: _isCardHovered ? -6 : -12,
                              offset: const Offset(0, 24),
                              color:
                              Colors.black.withOpacity(_isCardHovered ? 0.14 : 0.08),
                            ),
                          ],
                          border: Border.all(
                            color: Colors.white.withOpacity(
                                _isCardHovered ? 0.9 : 0.6),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Small pill badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: kPrimaryColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.lock_outline_rounded,
                                    size: 16,
                                    color: kSecondaryColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    "Secure login",
                                    style: textTheme.labelSmall?.copyWith(
                                      color: kSecondaryColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),

                            // App name / logo
                            Text(
                              "Halo.",
                              style: GoogleFonts.poppins(
                                fontSize: 36,
                                fontWeight: FontWeight.w800,
                                color: kSecondaryColor,
                                letterSpacing: 0.9,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Welcome back 👋",
                              style: textTheme.titleMedium?.copyWith(
                                color: Colors.grey.shade900,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Log in with your credentials to continue.",
                              textAlign: TextAlign.center,
                              style: textTheme.bodySmall?.copyWith(
                                color: Colors.grey.shade600,
                              ),
                            ),

                            const SizedBox(height: 28),

                            // Login ID label
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "Login ID",
                                style: textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),

                            // Login ID field
                            TextField(
                              controller: _loginIdController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              style: const TextStyle(color: Colors.black),
                              decoration: _inputDecoration(
                                hintText: "Username / Email / Phone",
                                prefixIcon: const Icon(
                                  Icons.person_outline_rounded,
                                  size: 22,
                                ),
                              ),
                            ),

                            const SizedBox(height: 18),

                            // Password label
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "Password / OTP",
                                style: textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),

                            // Password field
                            TextField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              style: const TextStyle(color: Colors.black),
                              decoration: _inputDecoration(
                                hintText: "Enter your password or OTP",
                                prefixIcon: const Icon(
                                  Icons.key_outlined,
                                  size: 22,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_rounded
                                        : Icons.visibility_rounded,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                              ),
                            ),

                            const SizedBox(height: 10),

                            Align(
                              alignment: Alignment.centerRight,
                              child: MouseRegion(
                                onEnter: (_) => setState(
                                        () => _isForgotHovered = true),
                                onExit: (_) => setState(
                                        () => _isForgotHovered = false),
                                child: TextButton(
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 0),
                                    tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ForgotPasswordPage(),
                                      ),
                                    );
                                  },
                                  child: Text(
                                    "Forgot password?",
                                    style: textTheme.labelSmall?.copyWith(
                                      color: _isForgotHovered
                                          ? kSecondaryColor
                                          : kSecondaryColor.withOpacity(0.85),
                                      fontWeight: FontWeight.w600,
                                      decoration: _isForgotHovered
                                          ? TextDecoration.underline
                                          : TextDecoration.none,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 22),

                            // Sign in button with hover
                            MouseRegion(
                              onEnter: (_) => setState(
                                      () => _isSignInHovered = true),
                              onExit: (_) => setState(
                                      () => _isSignInHovered = false),
                              child: AnimatedScale(
                                duration:
                                const Duration(milliseconds: 140),
                                scale:
                                _isSignInHovered ? 1.015 : 1.0,
                                child: SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed:
                                    _isLoading ? null : _signIn,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _isSignInHovered
                                          ? kSecondaryColor
                                          : kPrimaryColor,
                                      foregroundColor: Colors.white,
                                      elevation: _isSignInHovered ? 4 : 0,
                                      padding:
                                      const EdgeInsets.symmetric(
                                        vertical: 15,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                        BorderRadius.circular(20),
                                      ),
                                      textStyle: textTheme.labelLarge
                                          ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child:
                                      CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                        AlwaysStoppedAnimation<
                                            Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                        : Row(
                                      mainAxisAlignment:
                                      MainAxisAlignment.center,
                                      mainAxisSize:
                                      MainAxisSize.min,
                                      children: const [
                                        Icon(
                                          Icons.login_rounded,
                                          size: 18,
                                        ),
                                        SizedBox(width: 8),
                                        Text("Sign In"),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Create Account Link
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Don't have an account? ",
                                  style: textTheme.bodySmall?.copyWith(
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                MouseRegion(
                                  onEnter: (_) => setState(
                                          () => _isSignupHovered = true),
                                  onExit: (_) => setState(
                                          () => _isSignupHovered = false),
                                  child: GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              SignupPage(),
                                        ),
                                      );
                                    },
                                    child: Text(
                                      "Sign up",
                                      style: textTheme.bodySmall?.copyWith(
                                        color: _isSignupHovered
                                            ? kSecondaryColor
                                            : kSecondaryColor
                                            .withOpacity(0.9),
                                        fontWeight: FontWeight.w700,
                                        decoration: TextDecoration
                                            .underline,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 24),

                            // Divider with text
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 1,
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 8),
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                Text(
                                  "or continue with",
                                  style:
                                  textTheme.labelMedium?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    height: 1,
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 8),
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Google button with hover wrapper
                            MouseRegion(
                              onEnter: (_) => setState(
                                      () => _isGoogleHovered = true),
                              onExit: (_) => setState(
                                      () => _isGoogleHovered = false),
                              child: AnimatedScale(
                                duration:
                                const Duration(milliseconds: 120),
                                scale:
                                _isGoogleHovered ? 1.01 : 1.0,
                                child: AnimatedContainer(
                                  duration: const Duration(
                                      milliseconds: 140),
                                  decoration: BoxDecoration(
                                    borderRadius:
                                    BorderRadius.circular(16),
                                    boxShadow: _isGoogleHovered
                                        ? [
                                      BoxShadow(
                                        blurRadius: 18,
                                        spreadRadius: -4,
                                        offset: const Offset(0, 10),
                                        color: kPrimaryColor
                                            .withOpacity(0.35),
                                      ),
                                    ]
                                        : [],
                                  ),
                                  child: GoogleSignInButton(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
