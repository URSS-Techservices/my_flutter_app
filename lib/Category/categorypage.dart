import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/core/halo_theme.dart';
import 'package:halo/core/halo_toast.dart';
import 'package:halo/features/auth/presentation/onboarding_ui.dart';
import 'package:halo/features/auth/presentation/session_controller.dart';
import 'package:halo/screens/profile/core/profile_type.dart';

class CategoryPage extends ConsumerStatefulWidget {
  const CategoryPage({super.key});

  @override
  ConsumerState<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends ConsumerState<CategoryPage> {
  Future<void> _pick(ProfileKind kind) {
    return ref.read(authActionProvider.notifier).setAccountType(kind);
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(authActionProvider).isLoading;
    final padding = OnboardingUi.pagePadding(context);
    final textTheme = GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);

    ref.listen(authActionProvider, (prev, next) {
      next.whenOrNull(
        error: (e, _) => HaloToast.show('Could not save type: $e'),
      );
    });

    return Scaffold(
      backgroundColor: OnboardingUi.pageBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: OnboardingUi.maxWidth),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(8, 4, padding, 0),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: busy
                            ? null
                            : () =>
                                ref.read(authActionProvider.notifier).signOut(),
                        child: Text(
                          'Sign out',
                          style: GoogleFonts.poppins(
                            color: kPrimaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(padding, 8, padding, 24),
                    children: [
                      Text(
                        'Choose your path',
                        textAlign: TextAlign.center,
                        style: textTheme.headlineSmall?.copyWith(
                          color: OnboardingUi.text,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '',
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium?.copyWith(
                          color: OnboardingUi.muted,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 28),
                      if (busy)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 16),
                          child: LinearProgressIndicator(color: kPrimaryColor),
                        ),
                      _CategoryCard(
                        title: 'Wellness',
                        description:
                            '',
                        imagePath: 'assets/images/Wellness.png',
                        onTap: busy ? null : () => _pick(ProfileKind.wellness),
                      ),
                      const SizedBox(height: 14),
                      _CategoryCard(
                        title: 'Aspirant',
                        description:
                            '',
                        imagePath: 'assets/images/Aspirant.png',
                        onTap: busy ? null : () => _pick(ProfileKind.aspirant),
                      ),
                      const SizedBox(height: 14),
                      _CategoryCard(
                        title: 'Guru',
                        description:
                            '',
                        imagePath: 'assets/images/Guru.png',
                        onTap: busy ? null : () => _pick(ProfileKind.guru),
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

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.title,
    required this.description,
    required this.imagePath,
    required this.onTap,
  });

  final String title;
  final String description;
  final String imagePath;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: OnboardingUi.fieldBorder),
            boxShadow: [
              BoxShadow(
                color: kPrimaryColor.withValues(alpha: 0.12),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    imagePath,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 72,
                      height: 72,
                      color: OnboardingUi.fieldFill,
                      child: const Icon(Icons.person, color: OnboardingUi.muted),
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
                        style: textTheme.titleMedium?.copyWith(
                          color: OnboardingUi.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: textTheme.bodySmall?.copyWith(
                          color: OnboardingUi.muted,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: kPrimaryColor),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
