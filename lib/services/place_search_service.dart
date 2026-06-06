import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:http/http.dart' as http;

import 'package:halo/models/post_place.dart';

/// Instagram-style place search — Google Places via Cloud Function when
/// available, OpenStreetMap Nominatim fallback otherwise.
class PlaceSearchService {
  PlaceSearchService._();
  static final PlaceSearchService instance = PlaceSearchService._();

  static const _userAgent = 'HaloApp/1.0 (place search)';

  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  Future<List<PostPlace>> search({
    required String query,
    double? latitude,
    double? longitude,
  }) async {
    final q = query.trim();
    if (q.length < 2) return [];

    final fromCf = await _searchCloudFunction(
      functionName: 'searchPlaces',
      data: {
        'query': q,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      },
    );
    if (fromCf != null) return fromCf;

    return _searchNominatim(
      query: q,
      latitude: latitude,
      longitude: longitude,
    );
  }

  Future<List<PostPlace>> nearby({
    required double latitude,
    required double longitude,
  }) async {
    final fromCf = await _searchCloudFunction(
      functionName: 'nearbyPlaces',
      data: {
        'latitude': latitude,
        'longitude': longitude,
      },
    );
    if (fromCf != null) return fromCf;

    return _nearbyNominatim(latitude: latitude, longitude: longitude);
  }

  Future<List<PostPlace>?> _searchCloudFunction({
    required String functionName,
    required Map<String, dynamic> data,
  }) async {
    try {
      final result = await _functions.httpsCallable(functionName).call(data);
      final raw = result.data;
      if (raw is! Map) return null;
      final places = raw['places'];
      if (places is! List) return null;
      return places
          .map((e) {
            if (e is Map) {
              return PostPlace.fromMap(Map<String, dynamic>.from(e));
            }
            return PostPlace.fromMap(null);
          })
          .where((p) => p.isValid)
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<List<PostPlace>> _searchNominatim({
    required String query,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final params = <String, String>{
        'q': query,
        'format': 'jsonv2',
        'addressdetails': '1',
        'limit': '15',
        'dedupe': '1',
      };
      if (latitude != null && longitude != null) {
        const delta = 0.12;
        params['viewbox'] =
            '${longitude - delta},${latitude + delta},${longitude + delta},${latitude - delta}';
        params['bounded'] = '0';
      }
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', params);
      final response = await http.get(
        uri,
        headers: const {'User-Agent': _userAgent},
      );
      if (response.statusCode != 200) return [];
      final raw = jsonDecode(response.body);
      if (raw is! List) return [];
      final out = <PostPlace>[];
      final seen = <String>{};
      for (final item in raw) {
        if (item is! Map<String, dynamic>) continue;
        final place = _nominatimItemToPlace(item);
        if (place == null || !place.isValid) continue;
        if (seen.add(place.id)) out.add(place);
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  Future<List<PostPlace>> _nearbyNominatim({
    required double latitude,
    required double longitude,
  }) async {
    const terms = [
      'cafe',
      'restaurant',
      'coffee',
      'park',
      'mall',
      'hotel',
      'gym',
      'store',
    ];
    const delta = 0.018;
    final viewbox =
        '${longitude - delta},${latitude + delta},${longitude + delta},${latitude - delta}';

    final out = <PostPlace>[];
    final seen = <String>{};

    for (final term in terms) {
      try {
        final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
          'q': term,
          'format': 'jsonv2',
          'addressdetails': '1',
          'limit': '6',
          'viewbox': viewbox,
          'bounded': '1',
          'dedupe': '1',
        });
        final response = await http.get(
          uri,
          headers: const {'User-Agent': _userAgent},
        );
        if (response.statusCode != 200) continue;
        final raw = jsonDecode(response.body);
        if (raw is! List) continue;
        for (final item in raw) {
          if (item is! Map<String, dynamic>) continue;
          final place = _nominatimItemToPlace(item);
          if (place == null || !place.isValid) continue;
          if (seen.add(place.id)) out.add(place);
          if (out.length >= 20) break;
        }
      } catch (_) {}
      if (out.length >= 20) break;
    }

    out.sort((a, b) {
      final da = _distanceKm(latitude, longitude, a.latitude, a.longitude);
      final db = _distanceKm(latitude, longitude, b.latitude, b.longitude);
      return da.compareTo(db);
    });

    return out.take(15).toList();
  }

  PostPlace? _nominatimItemToPlace(Map<String, dynamic> item) {
    final lat = double.tryParse('${item['lat']}');
    final lon = double.tryParse('${item['lon']}');
    if (lat == null || lon == null) return null;

    final osmType = (item['osm_type'] ?? '').toString();
    final osmId = (item['osm_id'] ?? '').toString();
    final id = osmId.isNotEmpty ? 'osm:$osmType:$osmId' : 'nominatim:$lat,$lon';

    final display = (item['display_name'] ?? '').toString().trim();
    final named = (item['name'] ?? '').toString().trim();

    var name = named;
    if (name.isEmpty && display.isNotEmpty) {
      name = display.split(',').first.trim();
    }
    if (name.isEmpty) return null;

    final address = item['address'];
    var subtitle = '';
    if (address is Map<String, dynamic>) {
      final parts = <String>[];
      for (final k in [
        'house_number',
        'road',
        'suburb',
        'neighbourhood',
        'city',
        'town',
        'village',
        'state',
        'country',
      ]) {
        final v = (address[k] ?? '').toString().trim();
        if (v.isNotEmpty && !parts.contains(v)) parts.add(v);
      }
      subtitle = parts.join(', ');
    }
    if (subtitle.isEmpty && display.contains(',')) {
      subtitle = display.split(',').skip(1).join(',').trim();
    }

    return PostPlace(
      id: id,
      name: name,
      address: subtitle,
      latitude: lat,
      longitude: lon,
    );
  }

  static double _distanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) *
            math.cos(lat2 * p) *
            (1 - math.cos((lon2 - lon1) * p)) /
            2;
    return 12742 * math.asin(math.sqrt(a));
  }
}
