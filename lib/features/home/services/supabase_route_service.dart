import 'dart:convert';
import 'dart:math';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/constants/env.dart';
import '../models/preferences_data.dart';
import 'google_places_service.dart';

class WaypointStop {
  final LatLng latLng;
  final String name;

  const WaypointStop({required this.latLng, required this.name});
}

class SupabaseRouteService {
  const SupabaseRouteService();

  /// Calls the Supabase Edge Function `get-waypoints` and returns a list of
  /// POI stops to insert between [origin] and [destination].
  ///
  /// The current user's ID is read automatically from the active Supabase
  /// session (if logged in) and included in the request body.
  ///
  /// Returns an empty list if Supabase is not configured or the Edge Function
  /// hasn't been deployed yet — the caller falls back to a direct A→B route.
  Future<List<WaypointStop>> fetchWaypoints({
    required LatLng origin,
    required LatLng destination,
    required PreferencesData preferences,
  }) async {
    if (Env.supabaseUrl.isEmpty || Env.supabaseAnonKey.isEmpty) {
      return [];
    }

    final userId = Supabase.instance.client.auth.currentUser?.id;

    final url = Uri.parse('${Env.supabaseUrl}/functions/v1/get-waypoints');

    final body = <String, dynamic>{
      'origin': {
        'lat': origin.latitude,
        'lng': origin.longitude,
      },
      'destination': {
        'lat': destination.latitude,
        'lng': destination.longitude,
      },
      'preferences': {
        'shrines': preferences.shrines,
        'shopping': preferences.shopping,
        'cafes': preferences.cafes,
        'parks': preferences.parks,
        'added_duration': preferences.addedDuration,
      },
    };
    if (userId != null) body['user_id'] = userId;

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer ${Env.supabaseAnonKey}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw SupabaseRouteException(
        'Waypoints request failed (HTTP ${response.statusCode})',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final waypointsList = (data['waypoints'] as List?) ?? [];

    return waypointsList.map((w) {
      return WaypointStop(
        latLng: LatLng(
          (w['lat'] as num).toDouble(),
          (w['lng'] as num).toDouble(),
        ),
        name: w['name'] as String? ?? '',
      );
    }).toList();
  }
}

class SupabaseRouteException implements Exception {
  final String message;
  const SupabaseRouteException(this.message);

  @override
  String toString() => message;
}

// ---------------------------------------------------------------------------
// Dijkstra route + turn detection
// ---------------------------------------------------------------------------

class DijkstraRouteResult {
  final List<LatLng> points;
  final String distance;
  final String duration;
  final List<RouteStep> steps;
  final List<dynamic> chosenPois;

  const DijkstraRouteResult({
    required this.points,
    required this.distance,
    required this.duration,
    required this.steps,
    required this.chosenPois,
  });
}

extension DijkstraRoute on SupabaseRouteService {
  /// Calls the Supabase `get_dijkstra` RPC and returns a route with
  /// geometrically detected turn-by-turn steps.
  Future<DijkstraRouteResult> fetchDijkstraRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final dynamic raw = await Supabase.instance.client.rpc(
      'get_path',
      params: {
        'a_latitude': origin.latitude,
        'a_longitude': origin.longitude,
        'b_latitude': destination.latitude,
        'b_longitude': destination.longitude,
        'debug_mode': true,
      },
    );

    if (raw == null) {
      throw const SupabaseRouteException('get_path returned null');
    }

    // Back-compat:
    // - Old server: returns [[lat, lng], ...]
    // - New server: returns { path: [[lat, lng], ...], chosen_pois: [...] }
    final List<dynamic> pathList;
    final List<dynamic> chosenPois;
    if (raw is List) {
      pathList = raw;
      chosenPois = const [];
    } else if (raw is Map) {
      final dynamic maybePath = raw['path'];
      if (maybePath is! List) {
        throw const SupabaseRouteException('get_path did not return a valid path');
      }
      pathList = maybePath;
      final dynamic maybePois = raw['chosen_pois'];
      print('chosen_pois: $maybePois');
      chosenPois = maybePois is List ? maybePois : const [];
    } else {
      throw const SupabaseRouteException('get_path returned an unexpected shape');
    }

    if (pathList.isEmpty) {
      throw const SupabaseRouteException('get_path returned an empty path');
    }

    final points = pathList.map((e) {
      final pair = e as List<dynamic>;
      return LatLng(
        (pair[0] as num).toDouble(),
        (pair[1] as num).toDouble(),
      );
    }).toList();

    final totalMeters = _totalDistance(points);
    final steps = _detectTurns(points);

    return DijkstraRouteResult(
      points: points,
      distance: _formatDistance(totalMeters),
      duration: _formatDuration(totalMeters),
      steps: steps,
      chosenPois: chosenPois,
    );
  }
}

// ---------------------------------------------------------------------------
// Geometry helpers (module-private top-level functions)
// ---------------------------------------------------------------------------

/// Haversine distance in metres between two points.
double _haversineMeters(LatLng a, LatLng b) {
  const r = 6371000.0;
  final dLat = _toRad(b.latitude - a.latitude);
  final dLng = _toRad(b.longitude - a.longitude);
  final sinDLat = sin(dLat / 2);
  final sinDLng = sin(dLng / 2);
  final h = sinDLat * sinDLat +
      cos(_toRad(a.latitude)) * cos(_toRad(b.latitude)) * sinDLng * sinDLng;
  return 2 * r * asin(sqrt(h));
}

double _toRad(double deg) => deg * pi / 180;

/// Forward bearing A→B in degrees [0, 360).
double _bearing(LatLng a, LatLng b) {
  final lat1 = _toRad(a.latitude);
  final lat2 = _toRad(b.latitude);
  final dLng = _toRad(b.longitude - a.longitude);
  final y = sin(dLng) * cos(lat2);
  final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLng);
  return (atan2(y, x) * 180 / pi + 360) % 360;
}

/// Signed bearing change in (-180, 180]. Positive = right, negative = left.
double _bearingDelta(double inBearing, double outBearing) {
  return ((outBearing - inBearing + 540) % 360) - 180;
}

double _totalDistance(List<LatLng> pts) {
  double d = 0;
  for (int i = 0; i < pts.length - 1; i++) {
    d += _haversineMeters(pts[i], pts[i + 1]);
  }
  return d;
}

String _formatDistance(double meters) {
  if (meters >= 1000) {
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }
  return '${meters.round()} m';
}

String _formatDuration(double meters) {
  // Walking speed ≈ 5 km/h = 83.33 m/min
  final minutes = (meters / 83.33).round();
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h hr' : '$h hr $m min';
}

String _compassDirection(double bearing) {
  const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
  return dirs[((bearing + 22.5) / 45).floor() % 8];
}

/// Convert a list of coordinates into turn-by-turn [RouteStep]s by analysing
/// heading changes. Steps are merged into segments so that minor wiggles
/// (< 25°) don't generate spurious turns.
List<RouteStep> _detectTurns(List<LatLng> points) {
  if (points.length < 2) return [];

  // Pre-compute per-segment bearings.
  final bearings = <double>[
    for (int i = 0; i < points.length - 1; i++) _bearing(points[i], points[i + 1]),
  ];

  final steps = <RouteStep>[];
  double segmentMeters = 0;

  // First step: head in the initial direction.
  void addStep(String instruction, String? maneuver, double meters) {
    steps.add(RouteStep(
      instruction: instruction,
      distance: _formatDistance(meters),
      maneuver: maneuver,
    ));
  }

  // Walk through bearing transitions.
  for (int i = 1; i < bearings.length; i++) {
    segmentMeters += _haversineMeters(points[i - 1], points[i]);

    final delta = _bearingDelta(bearings[i - 1], bearings[i]);
    final absDelta = delta.abs();

    if (absDelta < 25) continue; // not a real turn

    // Emit a step for the segment just completed.
    if (steps.isEmpty) {
      addStep(
        'Head ${_compassDirection(bearings[0])}',
        'straight',
        segmentMeters,
      );
    } else {
      addStep(
        'Continue ${_compassDirection(bearings[i - 1])}',
        'straight',
        segmentMeters,
      );
    }

    // Emit the turn itself (zero distance — distance counted in next segment).
    String maneuver;
    String instruction;
    if (delta > 120) {
      maneuver = 'turn-sharp-right';
      instruction = 'Turn sharp right';
    } else if (delta > 45) {
      maneuver = 'turn-right';
      instruction = 'Turn right';
    } else if (delta > 25) {
      maneuver = 'turn-slight-right';
      instruction = 'Turn slight right';
    } else if (delta < -120) {
      maneuver = 'turn-sharp-left';
      instruction = 'Turn sharp left';
    } else if (delta < -45) {
      maneuver = 'turn-left';
      instruction = 'Turn left';
    } else {
      maneuver = 'turn-slight-left';
      instruction = 'Turn slight left';
    }
    steps.add(RouteStep(instruction: instruction, distance: '', maneuver: maneuver));

    segmentMeters = 0;
  }

  // Final segment leading to destination.
  segmentMeters += _haversineMeters(points[points.length - 2], points.last);
  if (steps.isEmpty) {
    addStep(
      'Head ${_compassDirection(bearings[0])}',
      'straight',
      segmentMeters,
    );
  }
  addStep('Arrive at destination', null, segmentMeters);

  return steps;
}
