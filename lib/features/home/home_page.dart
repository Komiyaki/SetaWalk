import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../shared/constants/app_constants.dart';
import 'models/place_prediction.dart';
import 'models/preferences_data.dart';
import 'models/search_field_type.dart';
import 'services/google_places_service.dart';
import 'services/location_service.dart';
import 'widgets/bottom_nav_bar.dart';
import 'widgets/map_compass.dart';
import 'widgets/preferences_drawer.dart';
import 'widgets/search_card.dart';
import 'widgets/settings_drawer.dart';
import 'widgets/suggestions_list.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GooglePlacesService _googlePlacesService = const GooglePlacesService();
  final LocationService _locationService = const LocationService();
  SupabaseClient get _sb => Supabase.instance.client;
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();

  final FocusNode _startFocusNode = FocusNode();
  final FocusNode _destinationFocusNode = FocusNode();

  GoogleMapController? _mapController;
  Timer? _debounce;

  List<PlacePrediction> _suggestions = [];
  bool _isLoadingSuggestions = false;
  bool _showSuggestions = false;
  String? _sessionToken;
  SearchFieldType? _activeSearchField;

  Position? _currentPosition;
  bool _isGettingLocation = true;
  final bool _useMockLocation = true;

  final Set<Marker> _markers = {};
  PreferencesData _preferences = const PreferencesData();

  double _cameraBearing = 0;

  bool get _hasStartFilled => _startController.text.trim().isNotEmpty;
  bool get _hasDestinationFilled =>
      _destinationController.text.trim().isNotEmpty;

  Marker? _findMarkerById(String id) {
    try {
      return _markers.firstWhere((marker) => marker.markerId.value == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> _onGoPressed() async {
    final hasStart = _hasStartFilled;
    final hasDestination = _hasDestinationFilled;

    if (!hasStart && !hasDestination) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please fill out both the starting point and destination.',
          ),
        ),
      );
      return;
    }

    if (!hasStart) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill out the starting point.')),
      );
      return;
    }

    if (!hasDestination) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill out the destination.')),
      );
      return;
    }

    final startMarker = _findMarkerById('start_place');
    final destinationMarker = _findMarkerById('destination_place');

    if (startMarker == null || destinationMarker == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not find both waypoint pins on the map yet.'),
        ),
      );
      return;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(
        startMarker.position.latitude < destinationMarker.position.latitude
            ? startMarker.position.latitude
            : destinationMarker.position.latitude,
        startMarker.position.longitude < destinationMarker.position.longitude
            ? startMarker.position.longitude
            : destinationMarker.position.longitude,
      ),
      northeast: LatLng(
        startMarker.position.latitude > destinationMarker.position.latitude
            ? startMarker.position.latitude
            : destinationMarker.position.latitude,
        startMarker.position.longitude > destinationMarker.position.longitude
            ? startMarker.position.longitude
            : destinationMarker.position.longitude,
      ),
    );

    await _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100),
    );
  }

  @override
  void initState() {
    super.initState();
    _setupFocusListeners();
  }

  void _setupFocusListeners() {
    _startFocusNode.addListener(() {
      if (_startFocusNode.hasFocus) {
        setState(() {
          _activeSearchField = SearchFieldType.start;
          if (_suggestions.isNotEmpty) {
            _showSuggestions = true;
          }
        });
      } else {
        _hideSuggestionsIfNoFieldIsFocused();
      }
    });

    _destinationFocusNode.addListener(() {
      if (_destinationFocusNode.hasFocus) {
        setState(() {
          _activeSearchField = SearchFieldType.destination;
          if (_suggestions.isNotEmpty) {
            _showSuggestions = true;
          }
        });
      } else {
        _hideSuggestionsIfNoFieldIsFocused();
      }
    });
  }

  void _hideSuggestionsIfNoFieldIsFocused() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;

      if (!_startFocusNode.hasFocus && !_destinationFocusNode.hasFocus) {
        setState(() {
          _showSuggestions = false;
        });
      }
    });
  }

  String _generateSessionToken() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
  Future<void> _savePreferencesToSupabase() async {
    final user = _sb.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be logged in to save preferences'),
        ),
      );
      return;
    }

    final payload = <String, dynamic>{
      'user': user.id,
      'shopping': _preferences.shopping.round(),
      'greenway': 0,
      'eating': _preferences.cafes.round(),
      'park': _preferences.parks.round(),
      'placeofworship': _preferences.shrines.round(),
      'added_duration': _preferences.addedDuration.round(),
    };

    try {
      await _sb.from('user_preferences').upsert(
            payload,
            onConflict: 'user',
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preferences saved')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }


  Future<void> _getCurrentLocation() async {
    final result = await _locationService.getCurrentLocation(
      useMockLocation: _useMockLocation,
    );

    if (!mounted) return;

    setState(() {
      _currentPosition = result.position;
      _isGettingLocation = false;
      _cameraBearing = 0;
    });

    await _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: result.cameraPosition.target,
          zoom: result.cameraPosition.zoom,
          bearing: 0,
          tilt: 0,
        ),
      ),
    );
  }

  Future<void> _resetMapNorth() async {
    await _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _currentPosition != null
              ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
              : AppConstants.initialCameraPosition.target,
          zoom: 16,
          bearing: 0,
          tilt: 0,
        ),
      ),
    );

    if (!mounted) return;

    setState(() {
      _cameraBearing = 0;
    });
  }

  TextEditingController? get _activeController {
    switch (_activeSearchField) {
      case SearchFieldType.start:
        return _startController;
      case SearchFieldType.destination:
        return _destinationController;
      case null:
        return null;
    }
  }

  void _clearSearch(SearchFieldType fieldType) {
    final controller = fieldType == SearchFieldType.start
        ? _startController
        : _destinationController;

    final markerId = fieldType == SearchFieldType.start
        ? 'start_place'
        : 'destination_place';

    controller.clear();
    _debounce?.cancel();

    setState(() {
      _markers.removeWhere((marker) => marker.markerId.value == markerId);
      _suggestions = [];
      _showSuggestions = false;
      _isLoadingSuggestions = false;
      _sessionToken = null;
      _activeSearchField = fieldType;
    });
  }

  void _onSearchChanged(String value, SearchFieldType fieldType) {
    _debounce?.cancel();

    setState(() {
      _activeSearchField = fieldType;
    });

    final trimmedValue = value.trim();

    if (trimmedValue.length < 2) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
        _isLoadingSuggestions = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;

      _sessionToken ??= _generateSessionToken();
      await _fetchAutocomplete(trimmedValue);
    });
  }

  Future<void> _fetchAutocomplete(String input) async {
    setState(() {
      _isLoadingSuggestions = true;
    });

    try {
      final predictions = await _googlePlacesService.fetchAutocomplete(
        input: input,
        sessionToken: _sessionToken ?? _generateSessionToken(),
      );

      if (!mounted) return;

      final activeController = _activeController;
      if (activeController == null || activeController.text.trim() != input) {
        return;
      }

      setState(() {
        _suggestions = predictions;
        _showSuggestions = true;
        _isLoadingSuggestions = false;
      });
    } on GooglePlacesException catch (error) {
      if (!mounted) return;

      setState(() {
        _suggestions = [];
        _showSuggestions = false;
        _isLoadingSuggestions = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _suggestions = [];
        _showSuggestions = false;
        _isLoadingSuggestions = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Network error: $error')));
    }
  }

  Future<void> _selectSuggestion(PlacePrediction prediction) async {
    final selectedField = _activeSearchField;
    if (selectedField == null) return;

    if (selectedField == SearchFieldType.start) {
      _startController.text = prediction.description;
    } else {
      _destinationController.text = prediction.description;
    }

    setState(() {
      _showSuggestions = false;
      _suggestions = [];
      _isLoadingSuggestions = false;
    });

    FocusScope.of(context).unfocus();

    final latLng = await _googlePlacesService.fetchPlaceDetails(
      placeId: prediction.placeId,
      sessionToken: _sessionToken ?? _generateSessionToken(),
    );

    if (!mounted) return;

    if (latLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not fetch place details')),
      );
      return;
    }

    await _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: latLng, zoom: 15.5, tilt: 0, bearing: 0),
      ),
    );

    setState(() {
      _cameraBearing = 0;

      final markerId = selectedField == SearchFieldType.start
          ? const MarkerId('start_place')
          : const MarkerId('destination_place');

      _markers.removeWhere((marker) => marker.markerId == markerId);

      _markers.add(
        Marker(
          markerId: markerId,
          position: latLng,
          infoWindow: InfoWindow(
            title: selectedField == SearchFieldType.start
                ? 'Start: ${prediction.mainText}'
                : 'Destination: ${prediction.mainText}',
          ),
          icon: selectedField == SearchFieldType.start
              ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)
              : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    });

    _sessionToken = null;
  }

  Future<void> _goToPlace(String query, SearchFieldType fieldType) async {
    final trimmedQuery = query.trim();

    if (trimmedQuery.length < 2) {
      return;
    }

    setState(() {
      _activeSearchField = fieldType;
    });

    _sessionToken ??= _generateSessionToken();
    await _fetchAutocomplete(trimmedQuery);

    if (!mounted) return;

    if (_suggestions.isNotEmpty) {
      await _selectSuggestion(_suggestions.first);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No results found')));
    }
  }

  Future<void> _savePreferences() async {
        Navigator.of(context).pop();
       await _savePreferencesToSupabase();
  }

  // void _savePreferences() {
  //   Navigator.of(context).pop();

  //   ScaffoldMessenger.of(context).showSnackBar(
  //     SnackBar(
  //       content: Text(
  //         'Preferences saved: '
  //         'Shrines ${_preferences.shrines.round()}, '
  //         'Shopping ${_preferences.shopping.round()}, '
  //         'Cafes ${_preferences.cafes.round()}, '
  //         'Parks ${_preferences.parks.round()}, '
  //         'Duration ${_preferences.addedDuration.round()}',
  //       ),
  //     ),
  //   );
  // }

  void _dismissKeyboardAndSuggestions() {
    FocusScope.of(context).unfocus();

    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;

      setState(() {
        _showSuggestions = false;
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _startController.dispose();
    _destinationController.dispose();
    _startFocusNode.dispose();
    _destinationFocusNode.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _dismissKeyboardAndSuggestions,
      child: Scaffold(
        key: _scaffoldKey,
        drawer: const SettingsDrawer(),
        endDrawer: PreferencesDrawer(
          preferences: _preferences,
          onShrinesChanged: (value) {
            setState(() {
              _preferences = _preferences.copyWith(shrines: value);
            });
          },
          onShoppingChanged: (value) {
            setState(() {
              _preferences = _preferences.copyWith(shopping: value);
            });
          },
          onCafesChanged: (value) {
            setState(() {
              _preferences = _preferences.copyWith(cafes: value);
            });
          },
          onParksChanged: (value) {
            setState(() {
              _preferences = _preferences.copyWith(parks: value);
            });
          },
          onAddedDurationChanged: (value) {
            setState(() {
              _preferences = _preferences.copyWith(addedDuration: value);
            });
          },
          onSave: _savePreferences,
        ),
        body: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: AppConstants.initialCameraPosition,
              mapToolbarEnabled: false,
              zoomControlsEnabled: false,
              myLocationEnabled: _currentPosition != null,
              myLocationButtonEnabled: _currentPosition != null,
              compassEnabled: false,
              rotateGesturesEnabled: true,
              tiltGesturesEnabled: true,
              markers: _markers,
              onMapCreated: (controller) async {
                _mapController = controller;
                await _getCurrentLocation();
              },
              onCameraMove: (position) {
                if (!mounted) return;

                setState(() {
                  _cameraBearing = position.bearing;
                });
              },
              onTap: (_) => _dismissKeyboardAndSuggestions(),
            ),

            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SearchCard(
                      startController: _startController,
                      destinationController: _destinationController,
                      startFocusNode: _startFocusNode,
                      destinationFocusNode: _destinationFocusNode,
                      onStartChanged: (value) =>
                          _onSearchChanged(value, SearchFieldType.start),
                      // onDestinationChanged: (value) =>
                      //     _onSearchChanged(value, SearchFieldType.destination),
                             onDestinationChanged: (value) => _onSearchChanged(
                        value,
                        SearchFieldType.destination,
                      ),
                      onStartSubmitted: (value) =>
                          _goToPlace(value, SearchFieldType.start),
                      onDestinationSubmitted: (value) =>
                          _goToPlace(value, SearchFieldType.destination),
                      onClearStart: () => _clearSearch(SearchFieldType.start),
                      onClearDestination: () =>
                          _clearSearch(SearchFieldType.destination),
                    ),
                    if (_showSuggestions)
                      SuggestionsList(
                        isLoading: _isLoadingSuggestions,
                        suggestions: _suggestions,
                        onSuggestionTap: _selectSuggestion,
                      ),
                  ],
                ),
              ),
            ),

            SafeArea(
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 90),
                  child: MapCompass(
                    bearing: _cameraBearing,
                    onTap: _resetMapNorth,
                  ),
                ),
              ),
            ),

            SafeArea(
              child: Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 16, bottom: 90),
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _onGoPressed,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                      child: const Text(
                        'Go',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            if (_isGettingLocation)
              const SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: EdgeInsets.only(top: 130),
                    child: Material(
                      elevation: 2,
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 10),
                            Text('Getting your location...'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        bottomNavigationBar: HomeBottomNavBar(
          onSettingsTap: () {
            _scaffoldKey.currentState?.openDrawer();
          },
          onMenuTap: () {
            _scaffoldKey.currentState?.openEndDrawer();
          },
        ),
      ),
    );
  }
}
