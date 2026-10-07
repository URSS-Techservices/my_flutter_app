import 'dart:async';

import 'package:geocoding/geocoding.dart';
import 'package:location/location.dart' as loc;

/// Result of a live location lookup: either a human-readable place name or
/// an error message that can be surfaced to the user.
class LocationLookup {
  final String? place;
  final String? error;
  final double? latitude;
  final double? longitude;

  const LocationLookup._({this.place, this.error, this.latitude, this.longitude});

  bool get isSuccess => place != null;
}

/// Fetches the device's current GPS fix and reverse-geocodes it into a
/// readable place name such as "Indiranagar, Bengaluru".
class LocationService {
  LocationService._();

  static final loc.Location _location = loc.Location();

  static Future<LocationLookup> fetchCurrentPlace({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      var serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) serviceEnabled = await _location.requestService();
      if (!serviceEnabled) {
        return const LocationLookup._(error: 'Please turn on location services.');
      }

      var permission = await _location.hasPermission();
      if (permission == loc.PermissionStatus.denied) {
        permission = await _location.requestPermission();
      }
      if (permission == loc.PermissionStatus.deniedForever) {
        return const LocationLookup._(
            error: 'Location permission is blocked. Enable it in Settings.');
      }
      if (permission != loc.PermissionStatus.granted &&
          permission != loc.PermissionStatus.grantedLimited) {
        return const LocationLookup._(error: 'Location permission is required.');
      }

      await _location.changeSettings(accuracy: loc.LocationAccuracy.high);
      final data = await _location.getLocation().timeout(timeout);
      final lat = data.latitude;
      final lng = data.longitude;
      if (lat == null || lng == null) {
        return const LocationLookup._(error: 'Unable to get your current position.');
      }

      final places = await placemarkFromCoordinates(lat, lng).timeout(timeout);
      final name = places.isEmpty ? null : _formatPlacemark(places.first);
      if (name == null) {
        return LocationLookup._(
            error: 'Could not find a place name for your position.',
            latitude: lat,
            longitude: lng);
      }
      return LocationLookup._(place: name, latitude: lat, longitude: lng);
    } on TimeoutException {
      return const LocationLookup._(error: 'Location request timed out. Try again.');
    } catch (e) {
      return LocationLookup._(error: 'Could not fetch location: $e');
    }
  }

  /// "Area, City" when both are known, otherwise the most specific non-empty
  /// component, falling back to state / country.
  static String? _formatPlacemark(Placemark p) {
    String clean(String? s) => (s ?? '').trim();
    final area = clean(p.subLocality);
    final city = clean(p.locality).isNotEmpty
        ? clean(p.locality)
        : clean(p.subAdministrativeArea);
    final state = clean(p.administrativeArea);
    final country = clean(p.country);

    final parts = <String>[];
    if (area.isNotEmpty && area != city) parts.add(area);
    if (city.isNotEmpty) parts.add(city);
    if (parts.isEmpty && state.isNotEmpty) parts.add(state);
    if (parts.length < 2 && state.isNotEmpty && !parts.contains(state)) parts.add(state);
    if (parts.isEmpty && country.isNotEmpty) parts.add(country);
    return parts.isEmpty ? null : parts.join(', ');
  }
}
