import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/Category/categorypage.dart'
    hide kPrimaryColor, kSecondaryColor, kDarkTop, kDarkBottom;
import 'package:halo/core/halo_theme.dart';
import 'package:halo/features/auth/presentation/pages/phone_login_page.dart';
import 'package:halo/features/auth/presentation/session_controller.dart';
import 'package:halo/features/auth/presentation/widgets/legal_dialogs.dart';
import 'package:halo/forgotpasswordpage.dart';

import 'package:halo/core/halo_toast.dart';

import '../widgets/login_button.dart';

/// Login UI only. All auth work goes through [authActionProvider], so this
/// page has no direct Firebase calls and stays testable.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref.read(authActionProvider.notifier).signInWithEmailOrUsername(
          identifier: _identifierController.text,
          password: _passwordController.text,
        );
  }

  Future<void> _sendOtp() async {
    final id = _identifierController.text.trim();
    if (id.isEmpty) {
      HaloToast.show(
          'Enter your username, mobile or email first',
      );
      return;
    }
    await ref
        .read(authActionProvider.notifier)
        .sendLoginOtp(identifier: id);

    if (!mounted) return;
    if (ref.read(authActionProvider).hasError) return;
    HaloToast.show('OTP sent to your email');
  }

  Future<void> _signInWithGoogle() async {
    await ref.read(authActionProvider.notifier).signInWithGoogle();
  }

  Future<void> _signInWithApple() async {
    await ref.read(authActionProvider.notifier).signInWithApple();
  }

  void _openPhoneLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PhoneLoginPage(),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 76,
      height: 76,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: kPrimaryColor.withValues(alpha: 0.25),
            blurRadius: 28,
            spreadRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/Halo.png',
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  void _openCreateAccount() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryPage(),
      ),
    );
  }

  void _openForgotPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ForgotPasswordPage(),
      ),
    );
  }

  InputDecoration _decoration({
    required String label,
    required String hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    final textTheme = GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: textTheme.labelMedium?.copyWith(
        color: Colors.black87,
        fontWeight: FontWeight.w600,
      ),
      hintStyle: textTheme.bodySmall?.copyWith(
          // color: Colors.white),
      color: Colors.black38),


      filled: true,
      fillColor: const Color(0xFFF7F5FA),
      // fillColor: Colors.white.withValues(alpha: 0.05),


      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,


      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Color(0xFFE7E3ED),
        ),
      ),


      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: kPrimaryColor, width: 1.5),
      ),



      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Colors.redAccent,
          width: 1.5,
        ),
      ),


      contentPadding:
          const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final action = ref.watch(authActionProvider);
    final busy = action.isLoading;

    ref.listen(authActionProvider, (previous, next) {
      final error = next.error;
      if (error != null && previous?.error != error) {
        HaloToast.show('$error');
      }
    });

    final textTheme = GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);

    return Scaffold(
      backgroundColor: const Color(0xFFF9F7FC),

      body:
      // Container(
      //   decoration: const BoxDecoration(
      //     gradient: LinearGradient(
      //       begin: Alignment.topCenter,
      //       end: Alignment.bottomCenter,
      //       colors: [Colors.white, Colors.white],          ),
      //   ),
      //   child:
      SafeArea(
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),

              padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                  ),



              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),


                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // _buildLogo(),

                    const SizedBox(height: 20),
                    Text(
                      'Halo.',
                      style: GoogleFonts.pacifico(
                        fontSize: 38,
                        fontWeight: FontWeight.bold,
                        fontStyle: FontStyle.italic,
                        color: kPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 30),
                    _LoginCard(
                      formKey: _formKey,
                      identifierController: _identifierController,
                      passwordController: _passwordController,
                      decoration: _decoration,
                      busy: busy,
                      obscurePassword: _obscurePassword,
                      onTogglePasswordVisibility: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      onSubmit: _signIn,
                      onSendOtp: _sendOtp,
                      textTheme: textTheme,
                    ),
                    const SizedBox(height: 8),
                    _FooterRow(textTheme: textTheme, busy: busy),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        const Expanded(
                          child: Divider(
                            color: Color(0xFFE5E1EA),
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Text(
                            'Or continue with',
                            style: textTheme.bodySmall?.copyWith(
                              color: Colors.black45,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),

                        const Expanded(
                          child: Divider(
                            color: Color(0xFFE5E1EA),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        LoginButton(
                          iconPath: 'assets/svg_icons/google.svg',
                          onTap: () {
                            if (busy) return;
                            _signInWithGoogle();
                          },
                        ),

                        const SizedBox(width: 14),

                        LoginButton(
                          iconPath: 'assets/svg_icons/fb.svg',
                          onTap: () {
                            // Facebook auth
                          },
                        ),

                        const SizedBox(width: 14),

                        LoginButton(
                          iconPath: 'assets/svg_icons/phone.svg',
                          onTap: () {
                            if (busy) return;
                            _openPhoneLogin();
                          },
                        ),

                        const SizedBox(width: 14),

                        LoginButton(
                          iconPath: 'assets/svg_icons/apple.svg',
                          onTap: () {
                            if (busy) return;
                            _signInWithApple();
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: 45),
                    _LegalLinks(textTheme: textTheme),
                  ],
                ),
              ),
            ),
          ),
        ),


    );
  }
}

typedef _DecorationBuilder = InputDecoration Function({
  required String label,
  required String hint,
  Widget? prefixIcon,
  Widget? suffixIcon,
});

class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.formKey,
    required this.identifierController,
    required this.passwordController,
    required this.decoration,
    required this.busy,
    required this.obscurePassword,
    required this.onTogglePasswordVisibility,
    required this.onSubmit,
    required this.onSendOtp,
    required this.textTheme,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController identifierController;
  final TextEditingController passwordController;
  final _DecorationBuilder decoration;
  final bool busy;
  final bool obscurePassword;
  final VoidCallback onTogglePasswordVisibility;
  final VoidCallback onSubmit;
  final VoidCallback onSendOtp;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: kPrimaryColor.withValues(alpha: 0.25),
            blurRadius: 28,
            spreadRadius: 20,
            offset: const Offset(0, 18),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
          width: 0.9,
        ),
      ),
      child: Form(
        key: formKey,
        child: Column(
          children: [
            TextFormField(
              controller: identifierController,
              style: const TextStyle(color: Colors.black87),
              decoration: decoration(
                label: 'Login ID',
                hint: 'Email ID',
                prefixIcon: const Icon(
                  Icons.person_outline_rounded,
                  color: Colors.black,
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter username, mobile or email';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: passwordController,
              style: const TextStyle(color: Colors.black87),
              obscureText: obscurePassword,
              decoration: decoration(
                label: 'Password',
                hint: 'Enter your password',
                prefixIcon: const Icon(
                  Icons.lock_outline_rounded,
                  color: Colors.black,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscurePassword
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: Colors.black87,
                  ),
                  onPressed: onTogglePasswordVisibility,
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your password or OTP';
                }
                return null;
              },
            ),

            const SizedBox(height: 50),
            // Align(
            //   alignment: Alignment.centerRight,
            //   child: TextButton(
            //     onPressed: busy ? null : onSendOtp,
            //     child: Text(
            //       'Send OTP',
            //       style: textTheme.bodySmall?.copyWith(
            //         color: kPrimaryColor,
            //         fontWeight: FontWeight.w600,
            //       ),
            //     ),
            //   ),
            // ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: busy ? null : onSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        'Sign In',
                        style: textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FooterRow extends StatelessWidget {
  const _FooterRow({required this.textTheme, required this.busy});

  final TextTheme textTheme;
  final bool busy;

  @override
  Widget build(BuildContext context) {
   const  SizedBox(height: 50);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(
              'New here? ',
              style: textTheme.bodySmall?.copyWith(color: Colors.black87),
            ),
            GestureDetector(
              onTap: busy
                  ? null
                  : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CategoryPage(),
                        ),
                      ),
              child: Text(
                'Create account',
                style: textTheme.bodySmall?.copyWith(
                  color: kPrimaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        GestureDetector(
          onTap: busy
              ? null
              : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ForgotPasswordPage(),
                    ),
                  ),
          child: Text(
            'Forgot Password?',
            style: textTheme.bodySmall?.copyWith(
              color: kPrimaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _LegalLinks extends StatelessWidget {
  const _LegalLinks({required this.textTheme});

  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => showTermsAndConditionsDialog(context),
          child: Text(
            'Terms & Conditions',
            style: textTheme.bodySmall?.copyWith(
              color: kPrimaryColor,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => showPrivacyPolicyDialog(context),
          child: Text(
            'Policy',
            style: textTheme.bodySmall?.copyWith(
              color: kPrimaryColor,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }
}
