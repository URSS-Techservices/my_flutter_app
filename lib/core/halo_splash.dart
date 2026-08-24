import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/core/halo_theme.dart';

/// Shown while Firebase / session streams are resolving.
class HaloSplash extends StatefulWidget {
  const HaloSplash({super.key});

  @override
  State<HaloSplash> createState() => _HaloSplashState();
}

class _HaloSplashState extends State<HaloSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _scale = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );
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
                Image.asset(
                  'assets/images/Halo.png',
                  height: 120,
                  width: 120,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 20),
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
                const _LoadingDots(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingDots extends StatefulWidget {
  const _LoadingDots();

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
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
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
            final offset = i * 0.25;
            final t = ((_ctrl.value - offset) % 1.0 + 1.0) % 1.0;
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
                  color: kPrimaryColor.withValues(alpha: 0.7),
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
