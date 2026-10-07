/// Social platforms a profile can link to.
///
/// Links are saved short (the part after the domain, e.g. `jchawla959` or
/// `@JuhiChawla`) under [key] in the `socialLinks` map, and turned back into
/// a full link with [urlFor]. Older full links still work.
enum SocialPlatform {
  instagram(
    key: 'instagram',
    label: 'Instagram',
    domain: 'instagram.com',
    fieldPrefix: 'instagram.com/',
  ),
  youtube(
    key: 'youtube',
    label: 'YouTube',
    domain: 'youtube.com',
    fieldPrefix: 'youtube.com/@',
  ),
  spotify(
    key: 'spotify',
    label: 'Spotify',
    domain: 'open.spotify.com',
    fieldPrefix: 'open.spotify.com/user/',
  ),
  netflix(
    key: 'netflix',
    label: 'Netflix',
    domain: 'netflix.com',
    fieldPrefix: '',
  );

  const SocialPlatform({
    required this.key,
    required this.label,
    required this.domain,
    required this.fieldPrefix,
  });

  final String key;
  final String label;
  final String domain;

  /// Shown before the input so users only type their handle.
  final String fieldPrefix;

  /// The platform whose domain appears in [input], if any.
  static SocialPlatform? detect(String input) {
    final lower = input.toLowerCase();
    for (final p in values) {
      if (lower.contains(p.domain) ||
          (p == youtube && lower.contains('youtu.be'))) {
        return p;
      }
    }
    return null;
  }

  /// Turns what the user typed or pasted into the short saved form.
  String toStored(String input) {
    var v = input.trim();
    if (v.isEmpty) return '';

    final lower = v.toLowerCase();
    final at = lower.indexOf(domain);
    if (at >= 0) {
      v = v.substring(at + domain.length);
      // Spotify adds "?si=…" tracking; other platforms keep the query
      // (a YouTube playlist link needs "?list=").
      if (this != youtube) v = v.split('?').first;
      v = v.replaceAll(RegExp(r'^/+|/+$'), '');
      return v;
    }
    if (v.startsWith('http://') || v.startsWith('https://')) return v;

    v = v.replaceFirst(RegExp(r'^@'), '').replaceAll(' ', '');
    return switch (this) {
      youtube => '@$v',
      spotify => 'user/$v',
      _ => v,
    };
  }

  /// Text to put back in the edit field for a saved value.
  String editText(String stored) {
    if (stored.startsWith('http')) return stored;
    return switch (this) {
      youtube when stored.startsWith('@') => stored.substring(1),
      spotify when stored.startsWith('user/') => stored.substring(5),
      instagram || netflix => stored,
      _ => 'https://$domain/$stored',
    };
  }

  String urlFor(String stored) {
    if (stored.startsWith('http')) return stored;
    if (this == netflix) return 'https://www.netflix.com/';
    return 'https://$domain/$stored';
  }

  /// Short label for the profile card, e.g. "@jchawla959" or "Playlist".
  String display(String stored) {
    if (stored.startsWith('http')) {
      return Uri.tryParse(stored)?.host.replaceFirst('www.', '') ?? stored;
    }
    if (stored.contains('playlist')) return 'Playlist';
    if (this == youtube && stored.startsWith('channel/')) return 'Channel';
    final last = stored.split('/').last;
    return switch (this) {
      instagram => '@$last',
      youtube => last.startsWith('@') ? last : '@$last',
      _ => last,
    };
  }

  /// Error text, or null if [stored] is fine.
  String? validate(String stored) {
    if (stored.isEmpty) return 'Enter your $label handle or link';
    if (stored.contains(' ')) return 'Remove spaces';
    if (stored.length > 200) return 'Too long';
    return null;
  }
}
