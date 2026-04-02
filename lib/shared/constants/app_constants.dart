import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:setawalk/shared/constants/env.dart';

class AppConstants {
  AppConstants._();

  static String get googleMapsApiKey => Env.googleMapsApiKey;
  static String get supabaseUrl => Env.supabaseUrl;
  static String get supabaseAnonKey => Env.supabaseAnonKey;

  static const LatLng setaMeguroCenter = LatLng(35.6467, 139.6530);

  static const CameraPosition initialCameraPosition = CameraPosition(
    target: setaMeguroCenter,
    zoom: 14,
  );
}