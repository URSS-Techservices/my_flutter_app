import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:halo/features/create_post/presentation/mention_controller.dart';

class MentionSuggestionsList extends ConsumerWidget {
  final void Function(String username) onSelect;

  const MentionSuggestionsList({super.key, required this.onSelect});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(mentionControllerProvider);
    if (!state.isVisible) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(blurRadius: 18, spreadRadius: -8, offset: const Offset(0, 10), color: Colors.black.withValues(alpha: 0.10)),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: state.suggestions.length,
        separatorBuilder: (_, __) => Divider(height: 0, color: Colors.grey.shade200),
        itemBuilder: (context, index) {
          final user = state.suggestions[index];
          final username = (user['username'] ?? '').toString();
          final fullName = (user['fullname'] ?? '').toString();
          final photoUrl = user['photoUrl'] as String?;

          return ListTile(
            leading: CircleAvatar(
              radius: 16,
              backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                  ? NetworkImage(photoUrl)
                  : const AssetImage('assets/images/Profile.png') as ImageProvider,
            ),
            title: Text('@$username', style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: fullName.isNotEmpty ? Text(fullName, style: const TextStyle(color: Colors.black87)) : null,
            onTap: () => onSelect(username),
          );
        },
      ),
    );
  }
}
