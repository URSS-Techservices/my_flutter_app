import 'package:flutter/material.dart';
import 'package:halo/core/halo_theme.dart';
import 'package:halo/features/feed/presentation/home_layout.dart';

class LoadingUi extends StatelessWidget {
  const LoadingUi({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(3, (_) => const _Row()),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row();

  @override
  Widget build(BuildContext context) {
    final h = HomeLayout.imageHeight(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              _box(36, 36, 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _box(120, 12, 6),
                    const SizedBox(height: 6),
                    _box(80, 10, 6),
                  ],
                ),
              ),
            ],
          ),
        ),
        _box(double.infinity, h, 0),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          child: Row(
            children: [
              _box(48, 14, 6),
              const SizedBox(width: 12),
              _box(48, 14, 6),
              const SizedBox(width: 12),
              _box(48, 14, 6),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFDBDBDB)),
      ],
    );
  }

  Widget _box(double w, double h, double r) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: const Color(0xFFF0EEF6),
        borderRadius: BorderRadius.circular(r),
      ),
    );
  }
}

class FeedErrorUi extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const FeedErrorUi({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(Icons.wifi_off_rounded, size: 40, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF8E8E8E), fontSize: 14),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: kSecondaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Retry', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
