import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meta/meta.dart';

class MapDataProcessor {
 
  static Polyline createPolylineFromJson(
    String jsonString,
    String id, {
    Color color = Colors.blue,
    int width = 5,
    bool geodesic = true,
  }) {
    final List<dynamic> decodedData = jsonDecode(jsonString);
    final List<LatLng> points = decodedData
        .map((item) => LatLng.fromJson(item))
        .whereType<LatLng>()
        .toList();


    return Polyline(
      polylineId: id,
      points: points,
      color: color,
      width: width,
      geodesic: geodesic,
    );
  }


  static Future<Polyline> createPolylineFromAsset(
    String assetPath,
    String id, {
    Color color = Colors.blue,
    int width = 5,
    bool geodesic = true,
  }) async {
    final jsonString = await rootBundle.loadString(assetPath);
    return createPolylineFromJson(
      jsonString,
      id,
      color: color,
      width: width,
      geodesic: geodesic,
    );
  }
}
class Polyline {
  const Polyline({
    required this.polylineId,
    this.consumeTapEvents = false,
    this.color = Colors.black,
    this.endCap = "buttCap",
    this.geodesic = false,
    this.jointType = "mitered",
    this.points = const <LatLng>[],
    this.patterns = const [],
    this.startCap = "buttCap",
    this.visible = true,
    this.width = 10,
    this.zIndex = 0,
    this.onTap,
  });


  final String polylineId;
  final bool consumeTapEvents;
  final Color color;
  final String endCap;
  final bool geodesic;
  final String jointType;
  final List<LatLng> points;
  final List<dynamic> patterns;
  final String startCap;
  final bool visible;
  final int width;
  final int zIndex;
  final VoidCallback? onTap;
}

@immutable
class LatLng {
  const LatLng(double latitude, double longitude)
      : latitude = latitude < -90.0 ? -90.0 : (90.0 < latitude ? 90.0 : latitude),
        longitude = longitude >= -180 && longitude < 180
            ? longitude
            : (longitude + 180.0) % 360.0 - 180.0;


  final double latitude;
  final double longitude;
 
  Object toJson() {
    return <double>[latitude, longitude];
  }

  static LatLng? fromJson(Object? json) {
    if (json == null) return null;
   
    if (json is List && json.length == 2) {
      return LatLng(
        (json[0] as num).toDouble(),
        (json[1] as num).toDouble()
      );
    }
    return null;
  }


  @override
  String toString() => 'LatLng($latitude, $longitude)';


  @override
  bool operator ==(Object other) =>
      other is LatLng &&
      other.latitude == latitude &&
      other.longitude == longitude;


  @override
  int get hashCode => Object.hash(latitude, longitude);
}
