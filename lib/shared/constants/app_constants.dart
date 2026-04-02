import 'package:google_maps_flutter/google_maps_flutter.dart';

class AppConstants {
  AppConstants._();

  static String get googleMapsApiKey {
    const key = String.fromEnvironment('GOOGLE_MAPS_API_KEY');
    if (key.isEmpty) {
      throw Exception('GOOGLE_MAPS_API_KEY is not set');
    }
    return key;
  }

  static String get supabaseUrl {
    const url = String.fromEnvironment('SUPABASE_URL');
    if (url.isEmpty) {
      throw Exception('SUPABASE_URL is not set');
    }
    return url;
  }

  static String get supabaseAnonKey {
    const key = String.fromEnvironment('SUPABASE_ANON_KEY');
    if (key.isEmpty) {
      throw Exception('SUPABASE_ANON_KEY is not set');
    }
    return key;
  }

  static const LatLng setaMeguroCenter = LatLng(35.6467, 139.6530);

  static const CameraPosition initialCameraPosition = CameraPosition(
    target: setaMeguroCenter,
    zoom: 14,
  );
}
