/// Extracts unique, lowercase `@mention` usernames from a caption.
List<String> extractMentions(String caption) {
  final regex = RegExp(r'@(\w+)');
  final matches = regex.allMatches(caption);
  final set = <String>{};
  for (final m in matches) {
    final username = m.group(1);
    if (username != null && username.trim().isNotEmpty) {
      set.add(username.toLowerCase());
    }
  }
  return set.toList();
}
