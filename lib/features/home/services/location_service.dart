import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../shared/constants/app_constants.dart';

class LocationResult {
  final Position? position;
  final CameraPosition cameraPosition;

  const LocationResult({
    required this.position,
    required this.cameraPosition,
  });
}

class LocationService {
  const LocationService();

  Future<LocationResult> getCurrentLocation({
    required bool useMockLocation,
  }) async {
    if (useMockLocation) {
      const mockLat = 35.6467;
      const mockLng = 139.6530;

      return LocationResult(
        position: Position(
          latitude: mockLat,
          longitude: mockLng,
          timestamp: DateTime.now(),
          accuracy: 1,
          altitude: 0,
          altitudeAccuracy: 1,
          heading: 0,
          headingAccuracy: 1,
          speed: 0,
          speedAccuracy: 1,
        ),
        cameraPosition: const CameraPosition(
          target: LatLng(mockLat, mockLng),
          zoom: 16,
        ),
      );
    }

    final fallbackResult = const LocationResult(
      position: null,
      cameraPosition: CameraPosition(
        target: AppConstants.setaMeguroCenter,
        zoom: 14,
      ),
    );

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return fallbackResult;
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return fallbackResult;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return fallbackResult;
      }

      Position? position;

      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 5),
          ),
        );
      } catch (_) {
        position = await Geolocator.getLastKnownPosition();
      }

      if (position == null) {
        return fallbackResult;
      }

      return LocationResult(
        position: position,
        cameraPosition: CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: 16,
        ),
      );
    } catch (_) {
      return fallbackResult;
    }
  }
}
