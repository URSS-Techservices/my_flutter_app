import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/core/halo_toast.dart';
import 'package:halo/features/auth/presentation/pages/login_page.dart';
import 'package:halo/features/auth/presentation/session_controller.dart';
const Color _kPrimary = Color(0xFFA58CE3);
const Color _kBgTop = Color(0xFF111111);
const Color _kBgBottom = Color(0xFF050505);

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);
    await ref
        .read(authActionProvider.notifier)
        .sendPasswordResetEmail(_emailController.text.trim());
    if (!mounted) return;
    setState(() => _isLoading = false);

    final error = ref.read(authActionProvider).error;
    if (error != null) {
      HaloToast.show(_friendlyResetError(error));
      return;
    }
    setState(() => _emailSent = true);
  }

  static String _friendlyResetError(Object error) {
    final text = error.toString();
    if (text.contains('user-not-found')) {
      return 'No account found with that email address.';
    }
    if (text.contains('invalid-email')) {
      return 'Please enter a valid email address.';
    }
    if (text.contains('too-many-requests')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    if (text.contains('network-request-failed')) {
      return 'No internet connection. Check your network.';
    }
    return 'Something went wrong. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final tt = GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Forgot Password',
          style: tt.titleMedium?.copyWith(
              fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_kBgTop, _kBgBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: kToolbarHeight + 10),

                // Icon
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.06),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.15), width: 1),
                  ),
                  child: Icon(
                    _emailSent
                        ? Icons.mark_email_read_rounded
                        : Icons.lock_reset_rounded,
                    size: 40,
                    color: _kPrimary,
                  ),
                ),
                const SizedBox(height: 18),

                Text(
                  _emailSent ? 'Check your inbox' : 'Reset your password',
                  style: tt.headlineSmall?.copyWith(
                      color: Colors.white, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),

                Text(
                  _emailSent
                      ? 'A reset link has been sent to\n${_emailController.text.trim()}\n\nCheck your spam folder if you don\'t see it.'
                      : "Enter the email linked with your account and we'll send you a reset link.",
                  textAlign: TextAlign.center,
                  style: tt.bodySmall?.copyWith(color: Colors.white70, height: 1.55),
                ),

                const SizedBox(height: 28),

                if (!_emailSent) ...[
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Enter your email',
                            labelStyle: tt.labelMedium?.copyWith(
                                color: Colors.grey.shade300,
                                fontWeight: FontWeight.w500),
                            hintText: 'you@example.com',
                            hintStyle: tt.bodySmall
                                ?.copyWith(color: Colors.grey.shade500),
                            prefixIcon: const Icon(Icons.email_outlined,
                                color: Colors.white70),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.06),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: const BorderSide(
                                  color: _kPrimary, width: 1.4),
                            ),
                            errorStyle:
                                const TextStyle(color: Colors.redAccent),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 16),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!RegExp(
                                    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
                                .hasMatch(v)) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _resetPassword,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _kPrimary,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18)),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation(
                                          Colors.white),
                                    ),
                                  )
                                : Text(
                                    'Send Reset Link',
                                    style: tt.labelLarge?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Resend option
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _emailSent = false;
                      _emailController.clear();
                    }),
                    icon: const Icon(Icons.refresh_rounded,
                        color: _kPrimary, size: 18),
                    label: Text(
                      'Send to a different email',
                      style: tt.bodySmall?.copyWith(
                          color: _kPrimary, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                GestureDetector(
                  onTap: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => LoginPage()),
                  ),
                  child: Text(
                    'Back to Login',
                    style: tt.bodySmall?.copyWith(
                      color: _kPrimary,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
