import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/core/halo_theme.dart';

class HaloFilledButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  const HaloFilledButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: kSecondaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          elevation: 2,
        ),
        child: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Text(
                label,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
      ),
    );
  }
}

class HaloOutlinedButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color? borderColor;
  final Widget? icon;

  const HaloOutlinedButton({
    super.key,
    required this.label,
    this.onPressed,
    this.borderColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final child = Text(
      label,
      style: GoogleFonts.poppins(
        color: const Color(0xFF1A1A2E),
        fontWeight: FontWeight.w600,
      ),
    );
    final style = OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      side: BorderSide(color: borderColor ?? kPrimaryColor),
      foregroundColor: const Color(0xFF1A1A2E),
    );
    final button = icon != null
        ? OutlinedButton.icon(
            onPressed: onPressed,
            icon: icon!,
            label: child,
            style: style,
          )
        : OutlinedButton(onPressed: onPressed, style: style, child: child);
    return SizedBox(width: double.infinity, child: button);
  }
}
