import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../theme/app_theme.dart';

/// Result returned from the location picker.
class LocationPickerResult {
  const LocationPickerResult({
    required this.latitude,
    required this.longitude,
    required this.address,
  });

  final double latitude;
  final double longitude;
  final String address;
}

class _LocationSearchSuggestion {
  const _LocationSearchSuggestion({
    required this.title,
    required this.address,
    required this.position,
  });

  factory _LocationSearchSuggestion.fromNominatim(Map<String, dynamic> json) {
    final String displayName = '${json['display_name'] ?? ''}'.trim();
    final Map<String, dynamic> address = json['address'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(json['address'] as Map<String, dynamic>)
        : const <String, dynamic>{};

    String firstAddressValue(List<String> keys) {
      for (final String key in keys) {
        final String value = '${address[key] ?? ''}'.trim();
        if (value.isNotEmpty) return value;
      }
      return '';
    }

    final String name = '${json['name'] ?? ''}'.trim();
    final String title = name.isNotEmpty
        ? name
        : displayName.split(',').first.trim();
    final List<String> addressParts = <String>[
      firstAddressValue(<String>['road', 'neighbourhood', 'suburb']),
      firstAddressValue(<String>[
        'city',
        'town',
        'village',
        'municipality',
        'city_district',
        'county',
      ]),
      firstAddressValue(<String>['state_district']),
      firstAddressValue(<String>['state']),
      firstAddressValue(<String>['postcode']),
    ].where((String value) => value.isNotEmpty).toList();

    final double latitude = double.tryParse('${json['lat'] ?? ''}') ?? 0;
    final double longitude = double.tryParse('${json['lon'] ?? ''}') ?? 0;

    return _LocationSearchSuggestion(
      title: title.isNotEmpty ? title : 'Selected location',
      address: addressParts.isNotEmpty ? addressParts.join(', ') : displayName,
      position: LatLng(latitude, longitude),
    );
  }

  factory _LocationSearchSuggestion.fromGooglePlace(Map<String, dynamic> json) {
    final Map<String, dynamic> geometry =
        json['geometry'] is Map<String, dynamic>
        ? json['geometry'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final Map<String, dynamic> location =
        geometry['location'] is Map<String, dynamic>
        ? geometry['location'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final double latitude = (location['lat'] as num?)?.toDouble() ?? 0;
    final double longitude = (location['lng'] as num?)?.toDouble() ?? 0;
    final String name = '${json['name'] ?? ''}'.trim();
    final String address = '${json['formatted_address'] ?? ''}'.trim();

    return _LocationSearchSuggestion(
      title: name.isNotEmpty
          ? name
          : (address.isNotEmpty ? address.split(',').first.trim() : 'Location'),
      address: address,
      position: LatLng(latitude, longitude),
    );
  }

  final String title;
  final String address;
  final LatLng position;
}

/// A full-screen sheet that shows a Google Map for picking a location.
/// User can tap on the map to place a pin, or use their current location.
/// Returns a [LocationPickerResult] when confirmed.
class LocationPickerSheet extends StatefulWidget {
  const LocationPickerSheet({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
  });

  final double? initialLatitude;
  final double? initialLongitude;

  @override
  State<LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<LocationPickerSheet> {
  static const LatLng _defaultCenter = LatLng(17.4401, 78.3489); // Hyderabad
  static const MethodChannel _configChannel = MethodChannel(
    'urban_easy_property_flutter_app/config',
  );
  static String? _cachedGooglePlacesApiKey;

  late LatLng _selectedLocation;
  String _address = '';
  bool _isLoadingAddress = false;
  bool _isSearching = false;
  GoogleMapController? _mapController;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _searchDebounce;
  List<_LocationSearchSuggestion> _suggestions = <_LocationSearchSuggestion>[];
  String? _searchError;

  @override
  void initState() {
    super.initState();
    final double? lat = widget.initialLatitude;
    final double? lng = widget.initialLongitude;
    if (lat != null && lng != null && lat != 0 && lng != 0) {
      _selectedLocation = LatLng(lat, lng);
    } else {
      _selectedLocation = _defaultCenter;
    }
    _reverseGeocode(_selectedLocation);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    final String query = value.trim();
    if (query.length < 3) {
      setState(() {
        _suggestions = <_LocationSearchSuggestion>[];
        _searchError = null;
      });
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      _loadSuggestions(query);
    });
  }

  Future<void> _searchPlace(String query) async {
    final String normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) return;
    if (_suggestions.isNotEmpty) {
      _selectSuggestion(_suggestions.first);
      return;
    }
    await _loadSuggestions(normalizedQuery, selectFirst: true);
  }

  Future<void> _loadSuggestions(
    String query, {
    bool selectFirst = false,
  }) async {
    final String normalizedQuery = query.trim();
    if (normalizedQuery.length < 3) return;
    setState(() {
      _isSearching = true;
      _searchError = null;
    });
    try {
      final List<_LocationSearchSuggestion> suggestions =
          await _fetchSearchSuggestions(normalizedQuery);
      if (!mounted) return;
      if (suggestions.isNotEmpty) {
        if (selectFirst) {
          _selectSuggestion(suggestions.first);
        } else {
          setState(() => _suggestions = suggestions);
        }
      } else {
        setState(() {
          _suggestions = <_LocationSearchSuggestion>[];
          _searchError = 'No locations found for that search.';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _suggestions = <_LocationSearchSuggestion>[];
        _searchError = 'Could not find the location. Try a different search.';
      });
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<List<_LocationSearchSuggestion>> _fetchSearchSuggestions(
    String query,
  ) async {
    final List<_LocationSearchSuggestion> googleSuggestions =
        await _fetchGooglePlacesSuggestions(query);
    if (googleSuggestions.isNotEmpty) {
      return googleSuggestions;
    }

    final List<_LocationSearchSuggestion> googleGeocodeSuggestions =
        await _fetchGoogleGeocodeSuggestions(query);
    if (googleGeocodeSuggestions.isNotEmpty) {
      return googleGeocodeSuggestions;
    }

    final List<_LocationSearchSuggestion> nominatimSuggestions =
        await _fetchNominatimSuggestions(query);
    if (nominatimSuggestions.isNotEmpty) {
      return nominatimSuggestions;
    }

    return _fetchGeocoderSuggestions(query);
  }

  Future<List<_LocationSearchSuggestion>> _fetchGooglePlacesSuggestions(
    String query,
  ) async {
    final String apiKey = await _googlePlacesApiKey();
    if (apiKey.trim().isEmpty) {
      return <_LocationSearchSuggestion>[];
    }

    final Uri uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/textsearch/json',
      <String, String>{'query': '$query India', 'region': 'in', 'key': apiKey},
    );

    try {
      final http.Response response = await http
          .get(uri)
          .timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return <_LocationSearchSuggestion>[];
      }

      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return <_LocationSearchSuggestion>[];
      }
      final String status = '${decoded['status'] ?? ''}';
      if (status != 'OK' && status != 'ZERO_RESULTS') {
        return <_LocationSearchSuggestion>[];
      }
      final List<dynamic> results = decoded['results'] is List<dynamic>
          ? decoded['results'] as List<dynamic>
          : const <dynamic>[];
      return _dedupeSuggestions(
        results
            .whereType<Map<String, dynamic>>()
            .map(_LocationSearchSuggestion.fromGooglePlace)
            .where(_hasValidPosition)
            .toList(),
      );
    } catch (_) {
      return <_LocationSearchSuggestion>[];
    }
  }

  Future<List<_LocationSearchSuggestion>> _fetchGoogleGeocodeSuggestions(
    String query,
  ) async {
    final String apiKey = await _googlePlacesApiKey();
    if (apiKey.trim().isEmpty) {
      return <_LocationSearchSuggestion>[];
    }

    final Uri uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/geocode/json',
      <String, String>{
        'address': '$query, India',
        'region': 'in',
        'components': 'country:IN',
        'key': apiKey,
      },
    );

    try {
      final http.Response response = await http
          .get(uri)
          .timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return <_LocationSearchSuggestion>[];
      }

      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return <_LocationSearchSuggestion>[];
      }
      final String status = '${decoded['status'] ?? ''}';
      if (status != 'OK' && status != 'ZERO_RESULTS') {
        return <_LocationSearchSuggestion>[];
      }
      final List<dynamic> results = decoded['results'] is List<dynamic>
          ? decoded['results'] as List<dynamic>
          : const <dynamic>[];
      return _dedupeSuggestions(
        results
            .whereType<Map<String, dynamic>>()
            .map(_LocationSearchSuggestion.fromGooglePlace)
            .where(_hasValidPosition)
            .toList(),
      );
    } catch (_) {
      return <_LocationSearchSuggestion>[];
    }
  }

  Future<String> _googlePlacesApiKey() async {
    final String? cached = _cachedGooglePlacesApiKey;
    if (cached != null) {
      return cached;
    }
    try {
      final String? key = await _configChannel.invokeMethod<String>(
        'googleMapsApiKey',
      );
      _cachedGooglePlacesApiKey = key?.trim() ?? '';
    } catch (_) {
      _cachedGooglePlacesApiKey = '';
    }
    return _cachedGooglePlacesApiKey!;
  }

  Future<List<_LocationSearchSuggestion>> _fetchNominatimSuggestions(
    String query,
  ) async {
    final Uri uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': '$query, India',
      'format': 'jsonv2',
      'addressdetails': '1',
      'limit': '8',
      'countrycodes': 'in',
    });
    final http.Response response = await http
        .get(
          uri,
          headers: const <String, String>{
            'Accept': 'application/json',
            'User-Agent': 'UrbanEasyPropertyFlutterApp/1.0',
          },
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is List<dynamic>) {
        return _dedupeSuggestions(
          decoded
              .whereType<Map<String, dynamic>>()
              .map(_LocationSearchSuggestion.fromNominatim)
              .where(_hasValidPosition)
              .toList(),
        );
      }
    }

    return <_LocationSearchSuggestion>[];
  }

  Future<List<_LocationSearchSuggestion>> _fetchGeocoderSuggestions(
    String query,
  ) async {
    final List<String> queries = <String>[
      '$query, Hyderabad, Telangana, India',
      '$query, Telangana, India',
      '$query, India',
      query,
    ];
    final List<_LocationSearchSuggestion> suggestions =
        <_LocationSearchSuggestion>[];

    for (final String lookup in queries) {
      try {
        final List<Location> locations = await locationFromAddress(lookup);
        suggestions.addAll(
          locations.map(
            (Location location) => _LocationSearchSuggestion(
              title: query,
              address:
                  '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}',
              position: LatLng(location.latitude, location.longitude),
            ),
          ),
        );
      } catch (_) {}
    }

    return _dedupeSuggestions(suggestions.where(_hasValidPosition).toList());
  }

  bool _hasValidPosition(_LocationSearchSuggestion suggestion) {
    return suggestion.position.latitude != 0 ||
        suggestion.position.longitude != 0;
  }

  List<_LocationSearchSuggestion> _dedupeSuggestions(
    List<_LocationSearchSuggestion> suggestions,
  ) {
    final Set<String> seen = <String>{};
    final List<_LocationSearchSuggestion> unique =
        <_LocationSearchSuggestion>[];
    for (final _LocationSearchSuggestion suggestion in suggestions) {
      final String key =
          '${suggestion.position.latitude.toStringAsFixed(6)},${suggestion.position.longitude.toStringAsFixed(6)}';
      if (seen.add(key)) {
        unique.add(suggestion);
      }
    }
    return unique;
  }

  void _selectSuggestion(_LocationSearchSuggestion suggestion) {
    final LatLng newPos = suggestion.position;
    _searchController.text = suggestion.title;
    _searchController.selection = TextSelection.collapsed(
      offset: _searchController.text.length,
    );
    setState(() {
      _selectedLocation = newPos;
      _address = suggestion.address.isNotEmpty
          ? suggestion.address
          : suggestion.title;
      _suggestions = <_LocationSearchSuggestion>[];
      _searchError = null;
      _isLoadingAddress = false;
    });
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(newPos, 15));
    _searchFocus.unfocus();
  }

  Future<void> _reverseGeocode(LatLng position) async {
    setState(() => _isLoadingAddress = true);
    try {
      final List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (!mounted) return;
      if (placemarks.isNotEmpty) {
        final Placemark place = placemarks.first;
        final List<String> parts = <String>[
          if (place.subLocality?.isNotEmpty == true) place.subLocality!,
          if (place.locality?.isNotEmpty == true) place.locality!,
          if (place.administrativeArea?.isNotEmpty == true)
            place.administrativeArea!,
          if (place.postalCode?.isNotEmpty == true) place.postalCode!,
        ];
        setState(() {
          _address = parts.join(', ');
          _isLoadingAddress = false;
        });
      } else {
        setState(() {
          _address =
              '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
          _isLoadingAddress = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _address =
            '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
        _isLoadingAddress = false;
      });
    }
  }

  Future<void> _goToCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied.')),
          );
          return;
        }
      }

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;
      final LatLng newPos = LatLng(position.latitude, position.longitude);
      setState(() {
        _selectedLocation = newPos;
        _suggestions = <_LocationSearchSuggestion>[];
        _searchError = null;
      });
      _mapController?.animateCamera(CameraUpdate.newLatLng(newPos));
      _reverseGeocode(newPos);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to get location: $e')));
    }
  }

  void _onMapTap(LatLng position) {
    setState(() {
      _selectedLocation = position;
      _suggestions = <_LocationSearchSuggestion>[];
      _searchError = null;
    });
    _reverseGeocode(position);
  }

  void _confirm() {
    Navigator.of(context).pop(
      LocationPickerResult(
        latitude: _selectedLocation.latitude,
        longitude: _selectedLocation.longitude,
        address: _address,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: const Text('Pick Location'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: AppTheme.border),
        ),
        actions: <Widget>[
          TextButton(onPressed: _confirm, child: const Text('Confirm')),
        ],
      ),
      body: Stack(
        children: <Widget>[
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _selectedLocation,
              zoom: 15,
            ),
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
            },
            onTap: _onMapTap,
            markers: <Marker>{
              Marker(
                markerId: const MarkerId('selected'),
                position: _selectedLocation,
                draggable: true,
                onDragEnd: (LatLng newPosition) {
                  setState(() {
                    _selectedLocation = newPosition;
                    _suggestions = <_LocationSearchSuggestion>[];
                    _searchError = null;
                  });
                  _reverseGeocode(newPosition);
                },
              ),
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),
          // Search bar at top
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(12),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocus,
                    decoration: InputDecoration(
                      hintText: 'Search location...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _isSearching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : IconButton(
                              icon: const Icon(Icons.arrow_forward_rounded),
                              onPressed: () =>
                                  _searchPlace(_searchController.text),
                            ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    onChanged: _onSearchChanged,
                    onSubmitted: _searchPlace,
                  ),
                ),
                if (_suggestions.isNotEmpty || _searchError != null)
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 280),
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(
                          color: Color(0x1A000000),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _suggestions.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(14),
                            child: Text(
                              _searchError ?? 'No locations found.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemCount: _suggestions.length,
                            separatorBuilder: (_, _) => const Divider(
                              height: 1,
                              color: AppTheme.borderSoft,
                            ),
                            itemBuilder: (BuildContext context, int index) {
                              final _LocationSearchSuggestion suggestion =
                                  _suggestions[index];
                              return ListTile(
                                dense: true,
                                leading: const Icon(
                                  Icons.location_on_outlined,
                                  color: AppTheme.primary,
                                ),
                                title: Text(
                                  suggestion.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  suggestion.address,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () => _selectSuggestion(suggestion),
                              );
                            },
                          ),
                  ),
              ],
            ),
          ),
          // Current location FAB
          Positioned(
            bottom: 100,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'locFab',
              backgroundColor: Colors.white,
              onPressed: _goToCurrentLocation,
              child: const Icon(
                Icons.my_location_rounded,
                color: AppTheme.primary,
              ),
            ),
          ),
          // Address bar at bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 12,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Icon(
                        Icons.location_on_rounded,
                        color: AppTheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _isLoadingAddress
                            ? Text(
                                'Finding address...',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppTheme.textMuted,
                                ),
                              )
                            : Text(
                                _address.isNotEmpty
                                    ? _address
                                    : 'Tap on map to select location',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Lat: ${_selectedLocation.latitude.toStringAsFixed(6)}, Lng: ${_selectedLocation.longitude.toStringAsFixed(6)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
