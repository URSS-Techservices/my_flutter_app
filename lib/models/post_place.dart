/// Structured place tag for posts (Instagram-style location pin).
class PostPlace {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;

  const PostPlace({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  /// Primary label shown on posts (place name only, like Instagram).
  String get displayLabel => name;

  /// Backward-compatible string for legacy `location` field readers.
  String get legacyLocation {
    if (address.isEmpty) return name;
    if (address.toLowerCase().contains(name.toLowerCase())) return address;
    return name;
  }

  Map<String, dynamic> toFirestore() => {
        'placeId': id,
        'locationName': name,
        'locationAddress': address,
        'latitude': latitude,
        'longitude': longitude,
        'location': legacyLocation,
      };

  factory PostPlace.fromMap(Map<String, dynamic>? data) {
    if (data == null) {
      return const PostPlace(
        id: '',
        name: '',
        address: '',
        latitude: 0,
        longitude: 0,
      );
    }
    final lat = _asDouble(data['latitude']);
    final lng = _asDouble(data['longitude']);
    final name = (data['locationName'] ?? data['name'] ?? '')
        .toString()
        .trim();
    final address = (data['locationAddress'] ?? data['address'] ?? '')
        .toString()
        .trim();
    final id = (data['placeId'] ?? data['id'] ?? '').toString().trim();
    if (name.isEmpty && lat == 0 && lng == 0) {
      final legacy = (data['location'] ?? '').toString().trim();
      return PostPlace(
        id: id,
        name: legacy,
        address: '',
        latitude: 0,
        longitude: 0,
      );
    }
    return PostPlace(
      id: id,
      name: name,
      address: address,
      latitude: lat,
      longitude: lng,
    );
  }

  static double _asDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  static String labelFromPostData(Map<String, dynamic> data) {
    final structured = (data['locationName'] ?? '').toString().trim();
    if (structured.isNotEmpty) return structured;
    return (data['location'] ?? '').toString().trim();
  }

  bool get hasCoordinates =>
      latitude.abs() > 1e-6 || longitude.abs() > 1e-6;

  bool get isValid => name.isNotEmpty && id.isNotEmpty && hasCoordinates;
}
