import 'package:flutter/material.dart';

class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(height: 180, color: Colors.grey.shade300),
          Transform.translate(
            offset: const Offset(0, -34),
            child: Center(
              child: CircleAvatar(
                radius: 42,
                backgroundColor: Colors.grey.shade200,
              ),
            ),
          ),
          _line(widthFactor: 0.4),
          const SizedBox(height: 10),
          _line(widthFactor: 0.25),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: const [
              _StatSkel(),
              _StatSkel(),
              _StatSkel(),
            ],
          ),
          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(child: _button()),
                const SizedBox(width: 10),
                Expanded(child: _button()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _line({required double widthFactor}) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: 14,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(7),
        ),
      ),
    );
  }

  static Widget _button() {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(24),
      ),
    );
  }
}

class _StatSkel extends StatelessWidget {
  const _StatSkel();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(width: 32, height: 14, color: Colors.grey.shade300),
        const SizedBox(height: 8),
        Container(width: 52, height: 12, color: Colors.grey.shade300),
      ],
    );
  }
}
