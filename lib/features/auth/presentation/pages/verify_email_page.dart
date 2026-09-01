import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/core/halo_theme.dart';
import 'package:halo/core/halo_toast.dart';
import 'package:halo/features/auth/presentation/session_controller.dart';

/// Shown by the gate whenever the signed-in email/password user has not
/// verified their address yet. No Firebase here — everything routes through
/// [authActionProvider]. Verification is mandatory before onboarding.
class VerifyEmailPage extends ConsumerWidget {
  const VerifyEmailPage({super.key});

  Future<void> _checkVerified(BuildContext context, WidgetRef ref) async {
    final verified =
        await ref.read(authActionProvider.notifier).reloadAndCheckEmailVerified();
    if (!context.mounted) return;
    if (verified) {
      // The session stream re-emits and the gate moves on automatically.
      HaloToast.show('Email verified. Setting up your profile…');
    } else {
      HaloToast.show('Not verified yet. Please tap the link in your email.');
    }
  }

  Future<void> _resend(BuildContext context, WidgetRef ref) async {
    await ref.read(authActionProvider.notifier).sendEmailVerification();
    if (!context.mounted) return;
    if (!ref.read(authActionProvider).hasError) {
      HaloToast.show(
        'Verification email sent again. Check inbox and spam.',
      );
    }
  }

  Future<void> _changeEmail(WidgetRef ref) async {
    // Signing out returns to the login page, where the user can start over.
    await ref.read(authActionProvider.notifier).signOut();
  }

  static String _friendlyVerifyError(Object error) {
    final text = error.toString();
    if (text.contains('too-many-requests')) {
      return 'Too many emails sent. Wait a minute, then try Resend.';
    }
    if (text.contains('network-request-failed')) {
      return 'No internet connection. Check your network.';
    }
    if (text.contains('user-not-found') || text.contains('Not signed in')) {
      return 'Please sign in again, then resend the email.';
    }
    return 'Could not send the verification email. Tap Resend.';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final action = ref.watch(authActionProvider);
    final busy = action.isLoading;
    final email = ref.watch(
      sessionProvider.select((s) => s.valueOrNull?.email),
    );
    final textTheme = GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);

    ref.listen(authActionProvider, (previous, next) {
      final error = next.error;
      if (error != null && previous?.error != error) {
        HaloToast.show(_friendlyVerifyError(error));
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF9F7FC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 72,
                    width: 72,
                    decoration: BoxDecoration(
                      color: kPrimaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(
                      Icons.mark_email_unread_outlined,
                      color: kPrimaryColor,
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Verify your email',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'We sent a verification link to:',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(color: Colors.black54),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    email ?? 'your email',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      color: Colors.black87,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Please check your inbox and spam folder, then come '
                    'back and tap the button below.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall?.copyWith(
                      color: Colors.black45,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: busy ? null : () => _checkVerified(context, ref),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
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
                              "I've Verified",
                              style: textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: busy ? null : () => _resend(context, ref),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kSecondaryColor,
                        side: const BorderSide(color: kPrimaryColor),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Resend Email'),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: busy ? null : () => _changeEmail(ref),
                    child: Text(
                      'Change Email',
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
