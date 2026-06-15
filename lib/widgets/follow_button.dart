import 'package:flutter/material.dart';

class FollowButton extends StatelessWidget {
  final bool isFollowing;
  final bool isLoading;
  final VoidCallback onPressed;

  const FollowButton({
    Key? key,
    required this.isFollowing,
    required this.isLoading,
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: ElevatedButton(
        key: ValueKey<bool>(isFollowing),
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isFollowing ? Colors.white : const Color(0xFF5B3FA3),
          foregroundColor: isFollowing ? Colors.black87 : Colors.white,
          side: isFollowing ? const BorderSide(color: Color(0xFF5B3FA3)) : null,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        ),
        child: isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(isFollowing ? 'Following' : 'Follow'),
      ),
    );
  }
}
