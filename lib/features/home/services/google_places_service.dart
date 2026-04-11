import 'dart:convert';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../../../shared/constants/app_constants.dart';
import '../models/place_prediction.dart';

class GooglePlacesService {
  const GooglePlacesService();

  Future<List<PlacePrediction>> fetchAutocomplete({
    required String input,
    required String sessionToken,
  }) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/autocomplete/json'
      '?input=${Uri.encodeComponent(input)}'
      '&key=${AppConstants.googleMapsApiKey}'
      '&sessiontoken=$sessionToken'
      '&components=country:jp'
      '&location=${AppConstants.setaMeguroCenter.latitude},${AppConstants.setaMeguroCenter.longitude}'
      '&radius=7500',
    );

    final response = await http.get(url);

    if (response.statusCode != 200) {
      throw const GooglePlacesException('Error fetching suggestions');
    }

    final data = jsonDecode(response.body);
    final status = data['status'];

    if (status == 'OK') {
      return (data['predictions'] as List)
          .map((item) => PlacePrediction.fromJson(item))
          .toList();
    }

    if (status == 'ZERO_RESULTS') {
      return [];
    }

    throw GooglePlacesException('Autocomplete error: $status');
  }

  Future<LatLng?> fetchPlaceDetails({
    required String placeId,
    required String sessionToken,
  }) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/details/json'
      '?place_id=${Uri.encodeComponent(placeId)}'
      '&fields=geometry,name'
      '&key=${AppConstants.googleMapsApiKey}'
      '&sessiontoken=$sessionToken',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode != 200) {
        return null;
      }

      final data = jsonDecode(response.body);
      if (data['status'] != 'OK') {
        return null;
      }

      final location = data['result']['geometry']['location'];
      final lat = (location['lat'] as num).toDouble();
      final lng = (location['lng'] as num).toDouble();

      return LatLng(lat, lng);
    } catch (_) {
      return null;
    }
  }

  Future<String?> reverseGeocode(LatLng latLng) async {
    // Run both calls concurrently and prefer the POI name if one exists nearby
    final results = await Future.wait([
      _nearbyPlaceName(latLng),
      _geocodedAddress(latLng),
    ]);
    return results[0] ?? results[1];
  }

  static const _excludedPlaceTypes = {
    'route',
    'street_address',
    'intersection',
    'locality',
    'sublocality',
    'neighborhood',
    'administrative_area_level_1',
    'administrative_area_level_2',
    'country',
    'postal_code',
  };

  Future<String?> _nearbyPlaceName(LatLng latLng) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
      '?location=${latLng.latitude},${latLng.longitude}'
      '&radius=30'
      '&key=${AppConstants.googleMapsApiKey}',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      if (data['status'] != 'OK') return null;

      final places = data['results'] as List;

      // Skip roads, routes, and administrative areas — only return actual POIs
      final poi = places.where((p) {
        final types = List<String>.from((p['types'] as List?) ?? []);
        return types.every((t) => !_excludedPlaceTypes.contains(t));
      }).toList();

      if (poi.isEmpty) return null;
      return poi.first['name'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<RouteResult> fetchWalkingRoute({
    required LatLng origin,
    required LatLng destination,
    List<LatLng> waypoints = const [],
  }) async {
    String waypointsParam = '';
    if (waypoints.isNotEmpty) {
      final encoded = waypoints
          .map((w) => '${w.latitude},${w.longitude}')
          .join('|');
      waypointsParam = '&waypoints=$encoded';
    }

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json'
      '?origin=${origin.latitude},${origin.longitude}'
      '&destination=${destination.latitude},${destination.longitude}'
      '&mode=walking'
      '$waypointsParam'
      '&key=${AppConstants.googleMapsApiKey}',
    );

    final response = await http.get(url);
    if (response.statusCode != 200) {
      throw GooglePlacesException(
        'Directions request failed (HTTP ${response.statusCode})',
      );
    }

    final data = jsonDecode(response.body);
    final status = data['status'] as String;
    if (status != 'OK') {
      final errorMsg = data['error_message'] as String? ?? 'no details';
      throw GooglePlacesException('Directions API: $status — $errorMsg');
    }

    final routes = data['routes'] as List;
    if (routes.isEmpty) {
      throw const GooglePlacesException('No route found');
    }

    final leg = routes[0]['legs'][0];
    final distance = leg['distance']['text'] as String;
    final duration = leg['duration']['text'] as String;
    final encoded = routes[0]['overview_polyline']['points'] as String;

    final rawSteps = (leg['steps'] as List?) ?? [];
    final steps = rawSteps.map((s) {
      return RouteStep(
        instruction: _stripHtml(s['html_instructions'] as String? ?? ''),
        distance: s['distance']['text'] as String,
        maneuver: s['maneuver'] as String?,
      );
    }).toList();

    return RouteResult(
      points: _decodePolyline(encoded),
      distance: distance,
      duration: duration,
      steps: steps,
    );
  }

  static String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&#39;', "'")
        .trim();
  }

  static List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    int index = 0;
    final len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : result >> 1;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : result >> 1;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }

    return points;
  }

  Future<String?> _geocodedAddress(LatLng latLng) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json'
      '?latlng=${latLng.latitude},${latLng.longitude}'
      '&key=${AppConstants.googleMapsApiKey}',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      if (data['status'] != 'OK') return null;

      final results = data['results'] as List;
      if (results.isEmpty) return null;

      return results[0]['formatted_address'] as String?;
    } catch (_) {
      return null;
    }
  }
}

class GooglePlacesException implements Exception {
  final String message;

  const GooglePlacesException(this.message);

  @override
  String toString() => message;
}

class RouteStep {
  final String instruction;
  final String distance;
  final String? maneuver;

  const RouteStep({
    required this.instruction,
    required this.distance,
    this.maneuver,
  });
}

class RouteResult {
  final List<LatLng> points;
  final String distance;
  final String duration;
  final List<RouteStep> steps;

  const RouteResult({
    required this.points,
    required this.distance,
    required this.duration,
    required this.steps,
  });
}
