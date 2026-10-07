import 'dart:convert';

import 'package:http/http.dart' as http;

/// One autocomplete suggestion, e.g. main "Lucknow", secondary
/// "Uttar Pradesh, India".
class PlaceSuggestion {
  final String placeId;
  final String mainText;
  final String secondaryText;

  /// [start, end) ranges inside [mainText] that matched the typed input.
  final List<(int, int)> matches;

  const PlaceSuggestion({
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
    this.matches = const [],
  });

  /// Value stored on the post: "Lucknow, Uttar Pradesh". The trailing country
  /// is dropped when there is something more specific to show.
  String get label {
    final parts = secondaryText
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.length >= 2) parts.removeLast();
    return [mainText, ...parts].join(', ');
  }
}

/// Google Places API (New) autocomplete. The key is supplied at build time:
///   flutter run --dart-define=PLACES_API_KEY=your_key
class PlacesService {
  PlacesService._();

  static const String _apiKey = String.fromEnvironment('PLACES_API_KEY');
  static final Uri _endpoint =
      Uri.parse('https://places.googleapis.com/v1/places:autocomplete');

  static bool get isConfigured => _apiKey.isNotEmpty;

  static Future<List<PlaceSuggestion>> autocomplete(String input) async {
    final query = input.trim();
    if (!isConfigured || query.length < 2) return const [];

    final res = await http
        .post(
          _endpoint,
          headers: {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': _apiKey,
          },
          body: jsonEncode({'input': query}),
        )
        .timeout(const Duration(seconds: 8));

    if (res.statusCode != 200) {
      throw Exception('Places autocomplete failed (${res.statusCode}): ${res.body}');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final suggestions = (body['suggestions'] as List?) ?? const [];
    final results = <PlaceSuggestion>[];
    for (final s in suggestions) {
      final p = (s as Map<String, dynamic>)['placePrediction'] as Map<String, dynamic>?;
      if (p == null) continue;
      final fmt = p['structuredFormat'] as Map<String, dynamic>?;
      final main = fmt?['mainText'] as Map<String, dynamic>?;
      final mainText = (main?['text'] ?? p['text']?['text'] ?? '') as String;
      if (mainText.isEmpty) continue;
      results.add(PlaceSuggestion(
        placeId: (p['placeId'] ?? '') as String,
        mainText: mainText,
        secondaryText: (fmt?['secondaryText']?['text'] ?? '') as String,
        matches: [
          for (final m in (main?['matches'] as List?) ?? const [])
            ((m['startOffset'] ?? 0) as int, (m['endOffset'] ?? 0) as int),
        ],
      ));
    }
    return results;
  }
}
