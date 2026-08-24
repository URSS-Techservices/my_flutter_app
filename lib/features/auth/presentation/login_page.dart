import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/Category/categorypage.dart'
    hide kPrimaryColor, kSecondaryColor, kDarkTop, kDarkBottom;
import 'package:halo/core/halo_theme.dart';
import 'package:halo/features/auth/presentation/session_controller.dart';
import 'package:halo/features/auth/presentation/widgets/google_sign_in_button.dart';
import 'package:halo/features/auth/presentation/widgets/legal_dialogs.dart';
import 'package:halo/forgotpasswordpage.dart';

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
        fontWeight: FontWeight.w500,
      ),
      hintStyle: textTheme.bodySmall?.copyWith(color: Colors.black54),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: kPrimaryColor, width: 1.5),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    final action = ref.watch(authActionProvider);
    final busy = action.isLoading;

    ref.listen(authActionProvider, (previous, next) {
      final error = next.error;
      if (error != null && previous?.error != error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: $error')),
        );
      }
    });

    final textTheme = GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [kDarkBackgroundTop, kDarkBackgroundBottom],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                      textTheme: textTheme,
                    ),
                    const SizedBox(height: 8),
                    _FooterRow(textTheme: textTheme, busy: busy),
                    const SizedBox(height: 32),
                    Text(
                      'Login with Social',
                      style: textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const GoogleSignInButton(),
                    const SizedBox(height: 36),
                    _LegalLinks(textTheme: textTheme),
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
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: kPrimaryColor.withValues(alpha: 0.25),
            blurRadius: 28,
            spreadRadius: -10,
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
              style: const TextStyle(color: Colors.white),
              decoration: decoration(
                label: 'Login ID',
                hint: 'Username / Mobile No. / Email ID',
                prefixIcon: const Icon(
                  Icons.person_outline_rounded,
                  color: Colors.white70,
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your username, mobile or email';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: passwordController,
              style: const TextStyle(color: Colors.white),
              obscureText: obscurePassword,
              decoration: decoration(
                label: 'Password / OTP',
                hint: 'Enter your password or OTP',
                prefixIcon: const Icon(
                  Icons.lock_outline_rounded,
                  color: Colors.white70,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscurePassword
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: Colors.white70,
                  ),
                  onPressed: onTogglePasswordVisibility,
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(
              'New here? ',
              style: textTheme.bodySmall?.copyWith(color: Colors.white70),
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
