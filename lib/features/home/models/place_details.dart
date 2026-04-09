import 'package:google_maps_flutter/google_maps_flutter.dart';

class PlaceDetails {
  final LatLng location;
  final String name;
  final String formattedAddress;

  const PlaceDetails({
    required this.location,
    required this.name,
    required this.formattedAddress,
  });
}