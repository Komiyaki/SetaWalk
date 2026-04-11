import 'dart:convert';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/constants/env.dart';
import '../models/preferences_data.dart';

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
