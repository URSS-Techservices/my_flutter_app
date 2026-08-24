import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/core/halo_theme.dart';
import 'package:halo/features/auth/presentation/session_controller.dart';
import 'package:halo/screens/profile/core/profile_type.dart';

/// Logged-in user with no `accountType` yet. Does not create a new Firebase user.
class ChooseAccountTypePage extends ConsumerWidget {
  const ChooseAccountTypePage({super.key});

  Future<void> _pick(WidgetRef ref, ProfileKind kind) {
    return ref.read(authActionProvider.notifier).setAccountType(kind);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final action = ref.watch(authActionProvider);
    final busy = action.isLoading;

    ref.listen(authActionProvider, (prev, next) {
      next.whenOrNull(
        error: (e, _) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not save type: $e')),
          );
        },
      );
    });

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [kDarkBackgroundTop, kDarkBackgroundBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: busy
                        ? null
                        : () => ref.read(authActionProvider.notifier).signOut(),
                    child: Text(
                      'Sign out',
                      style: GoogleFonts.poppins(color: kPrimaryColor),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose your account type',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You only pick this once. Login method does not change it.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 28),
                if (busy) const LinearProgressIndicator(color: kPrimaryColor),
                Expanded(
                  child: ListView(
                    children: [
                      _TypeCard(
                        title: 'Aspirant',
                        description:
                            'Find coaches, wellness spaces, and your fitness path.',
                        imagePath: 'assets/images/Aspirant.png',
                        onTap: busy
                            ? null
                            : () => _pick(ref, ProfileKind.aspirant),
                      ),
                      const SizedBox(height: 16),
                      _TypeCard(
                        title: 'Guru',
                        description:
                            'Share expertise and manage bookings with clients.',
                        imagePath: 'assets/images/Guru.png',
                        onTap: busy
                            ? null
                            : () => _pick(ref, ProfileKind.guru),
                      ),
                      const SizedBox(height: 16),
                      _TypeCard(
                        title: 'Wellness',
                        description:
                            'Promote your gym, studio, or wellness business.',
                        imagePath: 'assets/images/Wellness.png',
                        onTap: busy
                            ? null
                            : () => _pick(ref, ProfileKind.wellness),
                      ),
                    ],
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

class _TypeCard extends StatelessWidget {
  final String title;
  final String description;
  final String imagePath;
  final VoidCallback? onTap;

  const _TypeCard({
    required this.title,
    required this.description,
    required this.imagePath,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF221E36),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  imagePath,
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox(
                    width: 72,
                    height: 72,
                    child: Icon(Icons.person, color: Colors.white54),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: kPrimaryColor),
            ],
          ),
        ),
      ),
    );
  }
}
