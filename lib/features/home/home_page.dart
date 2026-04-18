import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/constants/app_constants.dart';
import 'models/place_prediction.dart';
import 'models/preferences_data.dart';
import 'models/search_field_type.dart';
import 'services/google_places_service.dart';
import 'services/location_service.dart';
import 'services/supabase_route_service.dart';
import 'widgets/bottom_nav_bar.dart';
import 'widgets/map_compass.dart';
import 'widgets/preferences_drawer.dart';
import 'widgets/search_card.dart';
import 'widgets/settings_drawer.dart';
import 'widgets/suggestions_list.dart';
import 'widgets/turn_by_turn_panel.dart';

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
  final SupabaseRouteService _supabaseRouteService =
      const SupabaseRouteService();

  final TextEditingController _startController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();

  final FocusNode _startFocusNode = FocusNode();
  final FocusNode _destinationFocusNode = FocusNode();

  GoogleMapController? _mapController;
  Timer? _debounce;
  Timer? _longPressTimer;
  Offset? _longPressStart;

  List<PlacePrediction> _suggestions = [];
  bool _isLoadingSuggestions = false;
  bool _showSuggestions = false;
  bool _showPreferences = false;
  String? _sessionToken;
  SearchFieldType? _activeSearchField;

  Position? _currentPosition;
  bool _isGettingLocation = true;
  final bool _useMockLocation = false;

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  LatLng? _startLatLng;
  LatLng? _destinationLatLng;
  String? _routeDistance;
  String? _routeDuration;
  List<RouteStep> _routeSteps = [];
  List<dynamic> _chosenPois = const [];
  BitmapDescriptor? _startMarkerIcon;
  BitmapDescriptor? _destinationMarkerIcon;
  BitmapDescriptor? _selectedMarkerIcon;
  BitmapDescriptor? _waypointMarkerIcon;
  bool _markerIconsInitialized = false;
  bool _isLoadingRoute = false;
  bool _isNavigating = false;
  String? _navigationDestination;
  PreferencesData _preferences = const PreferencesData();
  PreferencesData? _preferencesSnapshot;
  bool _isHandlingMapTap = false;

  final ValueNotifier<double> _cameraBearing = ValueNotifier(0);

  Future<void> _loadSavedPreferences() async {
    final prefs = await _loadPreferencesFromSupabase();
    if (prefs != null && mounted) {
      setState(() => _preferences = prefs);
    }
  }

  @override
  void initState() {
    super.initState();
    _setupFocusListeners();
    _loadSavedPreferences();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_markerIconsInitialized) {
      _markerIconsInitialized = true;
      _initMarkerIcons();
    }
  }

  void _initMarkerIcons() {
    setState(() {
      _startMarkerIcon = BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueGreen,
      );
      _destinationMarkerIcon = BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueRed,
      );
      _selectedMarkerIcon = BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueAzure,
      );
      _waypointMarkerIcon = BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueOrange,
      );
    });
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

  Future<PreferencesData?> _loadPreferencesFromSupabase() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;

    try {
      final data = await Supabase.instance.client
          .from('user_preferences')
          .select('shopping,eating,park,placeofworship,added_duration')
          .eq('user', user.id)
          .maybeSingle();

      if (data == null) return null;

      final map = (data as Map).cast<String, dynamic>();

      num _n(dynamic v, num fallback) => (v is num) ? v : fallback;

      return PreferencesData(
        shopping: _n(map['shopping'], 2).toDouble(),
        cafes: _n(map['eating'], 2).toDouble(),
        parks: _n(map['park'], 2).toDouble(),
        shrines: _n(map['placeofworship'], 2).toDouble(),
        addedDuration: _n(map['added_duration'], 100).toDouble(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _savePreferencesToSupabase() async {
    final user = _sb.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      _showSnackBar('You must be logged in to save preferences');
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
      await _sb.from('user_preferences').upsert(payload, onConflict: 'user');

      if (!mounted) return;
      _showSnackBar('Preferences saved');
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Save failed: $e');
    }
  }

  Future<void> _getCurrentLocation() async {
    final result = await _locationService.getCurrentLocation(
      useMockLocation: _useMockLocation,
    );

    if (!mounted) return;

    _cameraBearing.value = 0;
    setState(() {
      _currentPosition = result.position;
      _isGettingLocation = false;
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
    final bounds = await _mapController?.getVisibleRegion();
    if (bounds != null) {}
    final center = bounds != null
        ? LatLng(
            (bounds.northeast.latitude + bounds.southwest.latitude) / 2,
            (bounds.northeast.longitude + bounds.southwest.longitude) / 2,
          )
        : AppConstants.initialCameraPosition.target;

    await _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: center, zoom: 16, bearing: 0, tilt: 0),
      ),
    );

    if (!mounted) return;

    _cameraBearing.value = 0;
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
      _polylines.clear();
      _routeDistance = null;
      _routeDuration = null;
      _routeSteps = [];
      if (fieldType == SearchFieldType.start) {
        _startLatLng = null;
      } else {
        _destinationLatLng = null;
      }
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

      _showSnackBar(error.message);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _suggestions = [];
        _showSuggestions = false;
        _isLoadingSuggestions = false;
      });

      _showSnackBar('Network error: $error');
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
      _showSnackBar('Could not fetch place details');
      return;
    }

    await _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: latLng, zoom: 15.5, tilt: 0, bearing: 0),
      ),
    );

    final name = prediction.mainText;
    _cameraBearing.value = 0;
    setState(() {
      final markerId = selectedField == SearchFieldType.start
          ? const MarkerId('start_place')
          : const MarkerId('destination_place');

      if (selectedField == SearchFieldType.start) {
        _startLatLng = latLng;
      } else {
        _destinationLatLng = latLng;
      }

      _markers.removeWhere((marker) => marker.markerId == markerId);

      _markers.add(
        Marker(
          markerId: markerId,
          position: latLng,
          icon: selectedField == SearchFieldType.start
              ? (_startMarkerIcon ??
                    BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueGreen,
                    ))
              : (_destinationMarkerIcon ??
                    BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueRed,
                    )),
          onTap: () => _showLocationBottomSheet(name, latLng),
        ),
      );
    });

    _sessionToken = null;
    _clearActiveRoute();
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
      _showSnackBar('No results found');
    }
  }

  // Future<dynamic> goDijkstra() async {
  //   final start = _startLatLng;
  //   final destination = _destinationLatLng;
  //   if (start == null || destination == null) {
  //     throw StateError('Missing start/destination');
  //   }

  //   return goDijkstraRpc(
  //     rpc: (functionName, {params}) async =>
  //         await _sb.rpc(functionName, params: params),
  //     origin: start,
  //     destination: destination,
  //   );
  // }

  // List<LatLng> _decodeDijkstraPoints(String jsonString) {
  //   final decoded = jsonDecode(jsonString);
  //   if (decoded is! List) return const [];

  //   return decoded
  //       .map<LatLng?>((item) {
  //         if (item is List && item.length == 2) {
  //           final a = item[0];
  //           final b = item[1];
  //           if (a is num && b is num) {
  //             return LatLng(a.toDouble(), b.toDouble());
  //           }
  //         }
  //         return null;
  //       })
  //       .whereType<LatLng>()
  //       .toList();
  // }

  Future<void> _savePreferences() async {
    final unchanged = _preferencesSnapshot != null && _preferences == _preferencesSnapshot;
    setState(() {
      _showPreferences = false;
      _preferencesSnapshot = null;
    });
    if (unchanged) {
      _showSnackBar('No changes made!');
      return;
    }
    await _savePreferencesToSupabase();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Center(child: Text(message))),
    );
  }

  void _dismissKeyboardAndSuggestions() {
    _startFocusNode.unfocus();
    _destinationFocusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();

    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;

      setState(() {
        _showSuggestions = false;
      });
    });
  }

  Future<void> _onMapTap(LatLng latLng) async {
    if (_showSuggestions) {
      _dismissKeyboardAndSuggestions();
      return;
    }
    if (_isHandlingMapTap) return;
    _isHandlingMapTap = true;

    FocusScope.of(context).unfocus();

    setState(() {
      _markers.removeWhere((m) => m.markerId.value == 'selected_place');
      _markers.add(
        Marker(
          markerId: const MarkerId('selected_place'),
          position: latLng,
          icon:
              _selectedMarkerIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
      );
    });

    final name = await _googlePlacesService.reverseGeocode(latLng);
    if (!mounted) {
      _isHandlingMapTap = false;
      return;
    }

    final displayName =
        name ??
        '${latLng.latitude.toStringAsFixed(5)}, ${latLng.longitude.toStringAsFixed(5)}';

    await _showLocationBottomSheet(displayName, latLng);

    if (!mounted) {
      _isHandlingMapTap = false;
      return;
    }

    setState(() {
      _markers.removeWhere((m) => m.markerId.value == 'selected_place');
    });

    _isHandlingMapTap = false;
  }

  Future<void> _showLocationBottomSheet(String name, LatLng position) async {
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.grey, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _setAsStartingPoint(name, position);
                    },
                    icon: const Icon(Icons.radio_button_checked),
                    label: const Text('Starting Point'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green,
                      side: const BorderSide(color: Colors.green),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _setAsDestination(name, position);
                    },
                    icon: const Icon(Icons.location_on),
                    label: const Text('Destination'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _setAsStartingPoint(String name, LatLng position) {
    setState(() {
      _startController.text = name;
      _startLatLng = position;
      _markers
        ..removeWhere(
          (m) =>
              m.markerId.value == 'start_place' ||
              m.markerId.value == 'selected_place',
        )
        ..add(
          Marker(
            markerId: const MarkerId('start_place'),
            position: position,
            icon:
                _startMarkerIcon ??
                BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueAzure,
                ),
            onTap: () => _showLocationBottomSheet(name, position),
          ),
        );
    });
    _clearActiveRoute();
  }

  void _setAsDestination(String name, LatLng position) {
    setState(() {
      _destinationController.text = name;
      _destinationLatLng = position;
      _markers
        ..removeWhere(
          (m) =>
              m.markerId.value == 'destination_place' ||
              m.markerId.value == 'selected_place',
        )
        ..add(
          Marker(
            markerId: const MarkerId('destination_place'),
            position: position,
            icon:
                _destinationMarkerIcon ??
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            onTap: () => _showLocationBottomSheet(name, position),
          ),
        );
    });
    _clearActiveRoute();
  }

  void _clearActiveRoute() {
    setState(() {
      _polylines.clear();
      _routeDistance = null;
      _routeDuration = null;
      _routeSteps = [];
      _chosenPois = const [];
      _markers.removeWhere((m) => m.markerId.value.startsWith('waypoint_'));
      _markers.removeWhere((m) => m.markerId.value.startsWith('chosen_poi_'));
    });
  }

  Future<void> _onGo() async {
    // _showSnackBar('go button tapped');
    final start = _startLatLng;
    final destination = _destinationLatLng;
    if (start == null || destination == null) return;

    setState(() => _isLoadingRoute = true);
    FocusScope.of(context).unfocus();

    try {
      // print('Dijkstra starting');
      final result = await _supabaseRouteService.fetchDijkstraRoute(
        origin: start,
        destination: destination,
      );
        _showSnackBar(
        'Dijkstra ran',
      );
      print('Dijkstra function called, calculating route based on preferences...');
      if (!mounted) return;
      setState(() {
        _routeDistance = result.distance;
        _routeDuration = result.duration;
        _routeSteps = result.steps;
        _chosenPois = result.chosenPois;
        _polylines
          ..clear()
          ..add(
            Polyline(
              polylineId: const PolylineId('walking_route'),
              points: result.points,
              color: const Color(0xFF1A73E8),
              width: 5,
            ),
          );

        // Optional: show chosen POIs as markers if they include coordinates.
        _markers.removeWhere((m) => m.markerId.value.startsWith('chosen_poi_'));
        for (var i = 0; i < _chosenPois.length; i++) {
          final p = _chosenPois[i];
          if (p is! Map) continue;
          final lat = p['lat'];
          final lng = p['lng'];
          final color = p['tag_id'];
          //1 greenway (green)
          //2 shopping (pink)
          //3 eating (orsnge)
          //4 park (green)
          //5 place of worship (purple)
          if (lat is! num || lng is! num) continue;
          final name = ('Chosen POI ${i + 1}').toString();
          BitmapDescriptor getMarkerIcon(int tagId) {
          switch (tagId) {
            case 1:
            case 4:
              return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
            case 2:
              return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose);
            case 3:
              return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
            case 5:
              return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueMagenta);
            default:
            return BitmapDescriptor.defaultMarker;
          }
          }
          _markers.add(
            Marker(
              markerId: MarkerId('chosen_poi_$i'),
              position: LatLng(lat.toDouble(), lng.toDouble()),
              icon: _waypointMarkerIcon ?? getMarkerIcon(color ?? 0),
              onTap: () => _showLocationBottomSheet(
                name,
                LatLng(lat.toDouble(), lng.toDouble()),
              ),
            ),
          );
        }

        _isLoadingRoute = false;
        _isNavigating = true;
        _navigationDestination = _destinationController.text;
      });
      return;
    } catch (e) {
      _showSnackBar('Reverting to original path...');
    }

    // List<WaypointStop> waypointStops = [];
    // try {
    //   waypointStops = await _supabaseRouteService.fetchWaypoints(
    //     origin: start,
    //     destination: destination,
    //     preferences: _preferences,
    //   );
    // } on SupabaseRouteException catch (e) {
    //   if (!mounted) return;
    //   _showSnackBar(
    //     'Could not fetch waypoints: ${e.message}. Showing direct route.',
    //   );
    // } catch (_) {
    //   // Backend not yet deployed — fall back to direct route silently.
    // }

    // if (!mounted) return;
    // await _updateRoute(waypointStops.map((w) => w.latLng).toList());

    // if (!mounted) return;

    // // Place orange star markers for each waypoint POI
    // if (waypointStops.isNotEmpty) {
    //   setState(() {
    //     _markers.removeWhere((m) => m.markerId.value.startsWith('waypoint_'));
    //     for (var i = 0; i < waypointStops.length; i++) {
    //       final stop = waypointStops[i];
    //       _markers.add(
    //         Marker(
    //           markerId: MarkerId('waypoint_$i'),
    //           position: stop.latLng,
    //           icon:
    //               _waypointMarkerIcon ??
    //               BitmapDescriptor.defaultMarkerWithHue(
    //                 BitmapDescriptor.hueOrange,
    //               ),
    //           onTap: () => _showLocationBottomSheet(stop.name, stop.latLng),
    //         ),
    //       );
    //     }
    //   });
    // }

    setState(() {
      _isLoadingRoute = false;
      _isNavigating = true;
      _navigationDestination = _destinationController.text;
    });
  }

  void _onEnd() {
    setState(() {
      _isNavigating = false;
      _navigationDestination = null;
      _startLatLng = null;
      _destinationLatLng = null;
      _markers.clear();
      _polylines.clear();
      _routeDistance = null;
      _routeDuration = null;
      _routeSteps = [];
      _chosenPois = const [];
    });
    _startController.clear();
    _destinationController.clear();
  }

  // Future<void> _updateRoute(List<LatLng> waypoints) async {
  //   final start = _startLatLng;
  //   final destination = _destinationLatLng;

  //   if (start == null || destination == null) {
  //     _clearActiveRoute();
  //     return;
  //   }

  //   if (routePoints.isEmpty) return;

  //   final bounds = LatLngBounds(
  //     southwest: LatLng(
  //       min(start.latitude, destination.latitude),
  //       min(start.longitude, destination.longitude),
  //     ),
  //     northeast: LatLng(
  //       max(start.latitude, destination.latitude),
  //       max(start.longitude, destination.longitude),
  //     ),
  //   );

  //   await _mapController?.animateCamera(
  //     CameraUpdate.newLatLngBounds(bounds, 80),
  //   );
  // }

  Future<void> _useCurrentLocation() async {
    final position = _currentPosition;
    if (position == null) return;

    final latLng = LatLng(position.latitude, position.longitude);
    final name =
        await _googlePlacesService.reverseGeocode(latLng) ?? 'Current Location';

    if (!mounted) return;
    _setAsStartingPoint(name, latLng);
  }

  void _swapLocations() {
    final startText = _startController.text;
    final destText = _destinationController.text;
    final startLatLng = _startLatLng;
    final destLatLng = _destinationLatLng;

    _startController.text = destText;
    _destinationController.text = startText;

    setState(() {
      _startLatLng = destLatLng;
      _destinationLatLng = startLatLng;

      _markers.removeWhere(
        (m) =>
            m.markerId.value == 'start_place' ||
            m.markerId.value == 'destination_place',
      );

      if (destLatLng != null) {
        _markers.add(
          Marker(
            markerId: const MarkerId('start_place'),
            position: destLatLng,
            icon:
                _startMarkerIcon ??
                BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueAzure,
                ),
            onTap: () => _showLocationBottomSheet(destText, destLatLng),
          ),
        );
      }

      if (startLatLng != null) {
        _markers.add(
          Marker(
            markerId: const MarkerId('destination_place'),
            position: startLatLng,
            icon:
                _destinationMarkerIcon ??
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            onTap: () => _showLocationBottomSheet(startText, startLatLng),
          ),
        );
      }
    });

    _clearActiveRoute();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _longPressTimer?.cancel();
    _startController.dispose();
    _destinationController.dispose();
    _startFocusNode.dispose();
    _destinationFocusNode.dispose();
    _mapController?.dispose();
    _cameraBearing.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _dismissKeyboardAndSuggestions(),
      child: Scaffold(
        key: _scaffoldKey,
        resizeToAvoidBottomInset: false,
        drawer: const SettingsDrawer(),
        body: Stack(
          children: [
            Listener(
              onPointerDown: (event) {
                _longPressStart = event.localPosition;
                _longPressTimer?.cancel();
                _longPressTimer = Timer(
                  const Duration(milliseconds: 500),
                  () async {
                    if (!mounted) return;
                    final pos = _longPressStart;
                    if (pos == null) return;
                    final ratio = MediaQuery.of(context).devicePixelRatio;
                    final latLng = await _mapController?.getLatLng(
                      ScreenCoordinate(
                        x: (pos.dx * ratio).round(),
                        y: (pos.dy * ratio).round(),
                      ),
                    );
                    if (latLng != null && mounted) _onMapTap(latLng);
                  },
                );
              },
              onPointerMove: (event) {
                if (_longPressStart != null) {
                  final moved = (event.localPosition - _longPressStart!).distance;
                  if (moved > 10) {
                    _longPressTimer?.cancel();
                    _longPressTimer = null;
                  }
                }
              },
              onPointerUp: (_) {
                _longPressTimer?.cancel();
                _longPressTimer = null;
              },
              onPointerCancel: (_) {
                _longPressTimer?.cancel();
                _longPressTimer = null;
              },
              child: GoogleMap(
                initialCameraPosition: AppConstants.initialCameraPosition,
                mapToolbarEnabled: false,
                zoomControlsEnabled: false,
                myLocationEnabled: _currentPosition != null,
                myLocationButtonEnabled: false,
                compassEnabled: false,
                rotateGesturesEnabled: true,
                tiltGesturesEnabled: true,
                markers: _markers,
                polylines: _polylines,
                onMapCreated: (controller) async {
                  _mapController = controller;
                  await _getCurrentLocation();
                },
                onCameraMove: (position) {
                  _cameraBearing.value = position.bearing;
                },
                onTap: (_) => _dismissKeyboardAndSuggestions(),
              ),
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
                      onDestinationChanged: (value) =>
                          _onSearchChanged(value, SearchFieldType.destination),
                      onStartSubmitted: (value) =>
                          _goToPlace(value, SearchFieldType.start),
                      onDestinationSubmitted: (value) =>
                          _goToPlace(value, SearchFieldType.destination),
                      onClearStart: () => _clearSearch(SearchFieldType.start),
                      onClearDestination: () =>
                          _clearSearch(SearchFieldType.destination),
                      onUseCurrentLocation: _useCurrentLocation,
                      onSwap: _swapLocations,
                      isNavigating: _isNavigating,
                      navigationDestination: _navigationDestination,
                    ),
                    if (_showSuggestions)
                      SuggestionsList(
                        isLoading: _isLoadingSuggestions,
                        suggestions: _suggestions,
                        onSuggestionTap: _selectSuggestion,
                      ),
                    if (_routeDistance != null && _routeDuration != null) ...[
                      const SizedBox(height: 8),
                      TurnByTurnPanel(
                        distance: _routeDistance!,
                        duration: _routeDuration!,
                        steps: _routeSteps,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Bottom-left: compass (top) + location button (bottom)
            SafeArea(
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 108),
                  child: ValueListenableBuilder<double>(
                    valueListenable: _cameraBearing,
                    builder: (context, bearing, child) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Compass — fades in when map is off-north, hidden when north
                        IgnorePointer(
                          ignoring: bearing.abs() < 0.5,
                          child: AnimatedOpacity(
                            opacity: bearing.abs() < 0.5 ? 0.0 : 1.0,
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                            child: MapCompass(
                              bearing: bearing,
                              onTap: _resetMapNorth,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_currentPosition != null)
                          Material(
                            color: Colors.white,
                            elevation: 4,
                            shape: const CircleBorder(),
                            child: InkWell(
                              onTap: () => _mapController?.animateCamera(
                                CameraUpdate.newLatLng(
                                  LatLng(
                                    _currentPosition!.latitude,
                                    _currentPosition!.longitude,
                                  ),
                                ),
                              ),
                              customBorder: const CircleBorder(),
                              child: const SizedBox(
                                width: 48,
                                height: 48,
                                child: Icon(
                                  Icons.my_location,
                                  size: 24,
                                  color: Color(0xFF1A73E8),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Floating pill nav bar
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: HomeBottomNavBar(
                canGo: _startLatLng != null &&
                    _destinationLatLng != null &&
                    !_isLoadingRoute &&
                    !_isNavigating,
                isNavigating: _isNavigating,
                isLoadingRoute: _isLoadingRoute,
                onSettingsTap: () {
                  _startFocusNode.unfocus();
                  _destinationFocusNode.unfocus();
                  FocusManager.instance.primaryFocus?.unfocus();
                  _scaffoldKey.currentState?.openDrawer();
                },
                onGoTap: _onGo,
                onStopTap: _onEnd,
                onPreferencesTap: () {
                  if (_showPreferences) {
                    // Closing without save — restore snapshot
                    final hadChanges = _preferencesSnapshot != null &&
                        _preferences != _preferencesSnapshot;
                    setState(() {
                      if (_preferencesSnapshot != null) {
                        _preferences = _preferencesSnapshot!;
                        _preferencesSnapshot = null;
                      }
                      _showPreferences = false;
                    });
                    if (hadChanges) _showSnackBar('Preferences not saved! Click save to keep changes.');
                  } else {
                    // Opening — snapshot current state
                    setState(() {
                      _preferencesSnapshot = _preferences;
                      _showPreferences = true;
                    });
                  }
                },
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

            if (_showPreferences)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {
                    final hadChanges = _preferencesSnapshot != null &&
                        _preferences != _preferencesSnapshot;
                    setState(() {
                      if (_preferencesSnapshot != null) {
                        _preferences = _preferencesSnapshot!;
                        _preferencesSnapshot = null;
                      }
                      _showPreferences = false;
                    });
                    if (hadChanges) _showSnackBar('Preferences not saved');
                  },
                ),
              ),

            if (_showPreferences)
              Positioned(
                top: 200,
                right: 0,
                // Aligns with the bottom edge of the location button
                bottom: MediaQuery.of(context).padding.bottom + 108,
                child: PreferencesDrawer(
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
                      _preferences = _preferences.copyWith(
                        addedDuration: value,
                      );
                    });
                  },
                  onSave: _savePreferences,
                ),
              ),
          ],
        ),
      ),
    );
  }
}