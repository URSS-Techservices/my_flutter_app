import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:location/location.dart' as loc;

import 'package:halo/models/post_place.dart';
import 'package:halo/services/place_search_service.dart';

const Color _kPrimary = Color(0xFFA58CE3);
const Color _kSecondary = Color(0xFF5B3FA3);
const Color _kSurface = Color(0xFFEFECF8);
const Color _kBorder = Color(0xFFE8E4F0);
const Color _kText = Color(0xFF1A1A2E);
const Color _kSub = Color(0xFF888899);

/// Result from [LocationPickerSheet.show].
sealed class LocationPickerOutcome {
  const LocationPickerOutcome();
}

class LocationPickerDismissed extends LocationPickerOutcome {
  const LocationPickerDismissed();
}

class LocationPickerCleared extends LocationPickerOutcome {
  const LocationPickerCleared();
}

class LocationPickerSelected extends LocationPickerOutcome {
  final PostPlace place;
  const LocationPickerSelected(this.place);
}

/// Instagram-style place picker — search venues + nearby GPS suggestions.
class LocationPickerSheet extends StatefulWidget {
  final PostPlace? initial;

  const LocationPickerSheet({super.key, this.initial});

  static Future<LocationPickerOutcome> show(
    BuildContext context, {
    PostPlace? initial,
  }) async {
    final result = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LocationPickerSheet(initial: initial),
    );
    if (result == _clearToken) return const LocationPickerCleared();
    if (result is PostPlace) return LocationPickerSelected(result);
    return const LocationPickerDismissed();
  }

  static const Object _clearToken = Object();

  @override
  State<LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<LocationPickerSheet> {
  final _searchCtrl = TextEditingController();
  final _focus = FocusNode();

  Timer? _debounce;
  int _reqId = 0;

  List<PostPlace> _nearby = [];
  List<PostPlace> _results = [];
  bool _loadingNearby = false;
  bool _loadingSearch = false;
  String? _gpsError;

  double? _biasLat;
  double? _biasLng;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onQueryChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNearbyFromGps();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _loadNearbyFromGps() async {
    setState(() {
      _loadingNearby = true;
      _gpsError = null;
    });
    try {
      final location = loc.Location();
      if (!await location.serviceEnabled()) {
        await location.requestService();
      }
      var perm = await location.hasPermission();
      if (perm == loc.PermissionStatus.denied) {
        perm = await location.requestPermission();
      }
      if (perm != loc.PermissionStatus.granted &&
          perm != loc.PermissionStatus.grantedLimited) {
        if (mounted) {
          setState(() {
            _gpsError = 'Enable location to see nearby places';
            _loadingNearby = false;
          });
        }
        return;
      }
      final pos = await location.getLocation();
      final lat = pos.latitude;
      final lng = pos.longitude;
      if (lat == null || lng == null) {
        if (mounted) {
          setState(() {
            _gpsError = 'Could not read GPS coordinates';
            _loadingNearby = false;
          });
        }
        return;
      }
      _biasLat = lat;
      _biasLng = lng;
      final list = await PlaceSearchService.instance.nearby(
        latitude: lat,
        longitude: lng,
      );
      if (!mounted) return;
      setState(() {
        _nearby = list;
        _loadingNearby = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _gpsError = 'Nearby places unavailable';
          _loadingNearby = false;
        });
      }
    }
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    final q = _searchCtrl.text.trim();
    if (q.length < 2) {
      setState(() {
        _results = [];
        _loadingSearch = false;
      });
      return;
    }
    final id = ++_reqId;
    setState(() => _loadingSearch = true);
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      final list = await PlaceSearchService.instance.search(
        query: q,
        latitude: _biasLat,
        longitude: _biasLng,
      );
      if (!mounted || id != _reqId) return;
      setState(() {
        _results = list;
        _loadingSearch = false;
      });
    });
  }

  void _select(PostPlace place) => Navigator.pop(context, place);

  void _clear() => Navigator.pop(context, LocationPickerSheet._clearToken);

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final height = MediaQuery.sizeOf(context).height * 0.88;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        height: height,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Add location',
                      style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: _kText,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _clear,
                    child: Text(
                      'Remove',
                      style: GoogleFonts.poppins(
                        color: _kSub,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchCtrl,
                focusNode: _focus,
                autofocus: true,
                style: GoogleFonts.poppins(fontSize: 15, color: _kText),
                cursorColor: _kSecondary,
                decoration: InputDecoration(
                  hintText: 'Search places…',
                  hintStyle: GoogleFonts.poppins(color: _kSub, fontSize: 15),
                  prefixIcon: Icon(Icons.search_rounded, color: _kSecondary.withValues(alpha: 0.75)),
                  filled: true,
                  fillColor: _kSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: _kPrimary.withValues(alpha: 0.25)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: _kPrimary.withValues(alpha: 0.25)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _kSecondary, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _kPrimary.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.my_location_rounded, color: _kSecondary, size: 20),
              ),
              title: Text(
                'Use current location',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: _kText,
                ),
              ),
              subtitle: Text(
                'Show places near you',
                style: GoogleFonts.poppins(fontSize: 12, color: _kSub),
              ),
              onTap: _loadNearbyFromGps,
            ),
            const Divider(height: 1),
            Expanded(
              child: _buildList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    final q = _searchCtrl.text.trim();
    final searching = q.length >= 2;

    if (searching) {
      if (_loadingSearch) {
        return const Center(
          child: CircularProgressIndicator(color: _kSecondary, strokeWidth: 2),
        );
      }
      if (_results.isEmpty) {
        return Center(
          child: Text(
            'No places found for “$q”',
            style: GoogleFonts.poppins(color: _kSub, fontSize: 14),
          ),
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _results.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade100),
        itemBuilder: (_, i) => _PlaceRow(
          place: _results[i],
          onTap: () => _select(_results[i]),
        ),
      );
    }

    if (_loadingNearby) {
      return const Center(
        child: CircularProgressIndicator(color: _kSecondary, strokeWidth: 2),
      );
    }

    if (_nearby.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _gpsError ?? 'Search for a café, park, or place name',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: _kSub, fontSize: 14),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(
            'Nearby places',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _kSecondary,
            ),
          ),
        ),
        ..._nearby.map(
          (p) => _PlaceRow(place: p, onTap: () => _select(p)),
        ),
      ],
    );
  }
}

class _PlaceRow extends StatelessWidget {
  final PostPlace place;
  final VoidCallback onTap;

  const _PlaceRow({required this.place, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kBorder),
        ),
        child: Icon(Icons.place_outlined, color: _kSecondary, size: 22),
      ),
      title: Text(
        place.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: _kText,
        ),
      ),
      subtitle: place.address.isNotEmpty
          ? Text(
              place.address,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(fontSize: 12, color: _kSub, height: 1.3),
            )
          : null,
      trailing: Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
    );
  }
}
