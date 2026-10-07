import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/core/halo_theme.dart';
import 'package:halo/core/halo_toast.dart';
import 'package:halo/core/session.dart';
import 'package:halo/features/auth/presentation/session_controller.dart';

/// Dedicated email/password sign-up. This is the ONLY place email credentials
/// are entered — profile onboarding no longer collects them. On success the
/// user is signed in but unverified, so we pop back to the root and let the
/// reactive gate show the Verify Email page.
class EmailSignupPage extends ConsumerStatefulWidget {
  const EmailSignupPage({super.key});

  @override
  ConsumerState<EmailSignupPage> createState() => _EmailSignupPageState();
}

class _EmailSignupPageState extends ConsumerState<EmailSignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    await ref.read(authActionProvider.notifier).signUpWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

    if (!mounted) return;
    final error = ref.read(authActionProvider).error;
    if (error != null) {
      HaloToast.show(_friendlyError(error));
      // Account may already exist (send failed after create). Still open
      // Verify Email so the user can tap Resend.
      final status = ref.read(sessionProvider).valueOrNull?.status;
      if (status != SessionStatus.emailVerificationRequired) return;
    } else {
      HaloToast.show(
        'Verification email sent. Check inbox and spam.',
      );
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  String? _emailValidator(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Please enter your email';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) {
      return 'Please enter a valid email';
    }
    return null;
  }

  String? _passwordValidator(String? value) {
    if (value == null || value.isEmpty) return 'Please enter a password';
    if (value.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  String? _confirmValidator(String? value) {
    if (value == null || value.isEmpty) return 'Please confirm your password';
    if (value != _passwordController.text) return 'Passwords do not match';
    return null;
  }

  static String _friendlyError(Object error) {
    final text = error.toString();
    if (text.contains('email-already-in-use')) {
      return 'This email is already registered. Try signing in instead.';
    }
    if (text.contains('invalid-email')) return 'That email is not valid.';
    if (text.contains('weak-password')) {
      return 'That password is too weak. Use at least 6 characters.';
    }
    if (text.contains('too-many-requests')) {
      return 'Too many emails sent. Wait a minute, then tap Resend.';
    }
    if (text.contains('network-request-failed')) {
      return 'No internet connection. Check your network.';
    }
    if (text.contains('missing-email') || text.contains('invalid-email')) {
      return 'That email is not valid.';
    }
    return 'Could not create your account. Please try again.';
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
      hintStyle: textTheme.bodySmall?.copyWith(color: Colors.black38),
      filled: true,
      fillColor: const Color(0xFFF7F5FA),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE7E3ED)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: kPrimaryColor, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    final action = ref.watch(authActionProvider);
    final busy = action.isLoading;
    final textTheme = GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);

    ref.listen(authActionProvider, (previous, next) {
      final error = next.error;
      if (error != null && previous?.error != error) {
        HaloToast.show(_friendlyError(error));
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF9F7FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Create account',
                    style: GoogleFonts.poppins(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Sign up with your email. We will send a verification link '
                    'to confirm it is really you.',
                    style: textTheme.bodySmall?.copyWith(color: Colors.black54),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: kPrimaryColor.withValues(alpha: 0.20),
                          blurRadius: 28,
                          spreadRadius: 8,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(color: Colors.black87),
                            decoration: _decoration(
                              label: 'Email',
                              hint: 'you@example.com',
                              prefixIcon: const Icon(Icons.email_outlined,
                                  color: Colors.black54),
                            ),
                            validator: _emailValidator,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: const TextStyle(color: Colors.black87),
                            decoration: _decoration(
                              label: 'Password',
                              hint: 'At least 6 characters',
                              prefixIcon: const Icon(Icons.lock_outline_rounded,
                                  color: Colors.black54),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                  color: Colors.black54,
                                ),
                                onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            validator: _passwordValidator,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _confirmController,
                            obscureText: _obscureConfirm,
                            style: const TextStyle(color: Colors.black87),
                            decoration: _decoration(
                              label: 'Confirm Password',
                              hint: 'Re-enter your password',
                              prefixIcon: const Icon(Icons.lock_rounded,
                                  color: Colors.black54),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirm
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                  color: Colors.black54,
                                ),
                                onPressed: () => setState(
                                    () => _obscureConfirm = !_obscureConfirm),
                              ),
                            ),
                            validator: _confirmValidator,
                            onFieldSubmitted: (_) {
                              if (!busy) _submit();
                            },
                          ),
                          const SizedBox(height: 28),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: busy ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kPrimaryColor,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 13),
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
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                            Colors.white),
                                      ),
                                    )
                                  : Text(
                                      'Create Account',
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
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: busy ? null : () => Navigator.pop(context),
                    child: Text(
                      'Already have an account? Sign in',
                      style: textTheme.bodySmall?.copyWith(
                        color: kPrimaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
