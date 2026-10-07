import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfileEmptyStateRich extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color? iconColor;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool card;
  final Color? cardColor;
  final Color? textColor;
  final Color? actionBackgroundColor;
  final Color? actionForegroundColor;

  const ProfileEmptyStateRich({
    super.key,
    required this.text,
    this.icon,
    this.iconColor,
    this.actionLabel,
    this.onAction,
    this.card = false,
    this.cardColor,
    this.textColor,
    this.actionBackgroundColor,
    this.actionForegroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 48, color: iconColor ?? Colors.grey[400]),
          const SizedBox(height: 8),
        ],
        Text(
          text,
          style: GoogleFonts.poppins(color: textColor),
          textAlign: TextAlign.center,
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.add, size: 18),
            label: Text(actionLabel!),
            style: ElevatedButton.styleFrom(
              backgroundColor: actionBackgroundColor,
              foregroundColor: actionForegroundColor,
            ),
          ),
        ],
      ],
    );

    if (!card) return Center(child: content);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor ?? Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(child: content),
    );
  }
}
