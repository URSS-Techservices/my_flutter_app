import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:halo/features/auth/presentation/session_controller.dart';

/// Thin UI. All auth work happens in [AuthRepository] via
/// [authActionProvider]. The button does not touch Firebase or Google APIs.
class GoogleSignInButton extends ConsumerWidget {
  const GoogleSignInButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final action = ref.watch(authActionProvider);
    final busy = action.isLoading;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: busy
            ? null
            : () => ref.read(authActionProvider.notifier).signInWithGoogle(),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: const BorderSide(color: Colors.grey),
        ),
        child: busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Sign in with Google'),
      ),
    );
  }
}
