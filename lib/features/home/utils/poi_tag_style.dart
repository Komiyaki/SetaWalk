import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// 1 greenway, 2 shopping, 3 eating, 4 park, 5 place of worship
class PoiTagStyle {
  static const int greenway = 1;
  static const int shopping = 2;
  static const int eating = 3;
  static const int park = 4;
  static const int placeOfWorship = 5;

  static BitmapDescriptor markerIconForTagId(Object? tagId) {
    final id = _coerceInt(tagId);
    switch (id) {
      case greenway:
      case park:
        return BitmapDescriptor.defaultMarkerWithHue(160);
      case shopping:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose);
      case eating:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
      case placeOfWorship:
        return BitmapDescriptor.defaultMarkerWithHue(270);
      default:
        return BitmapDescriptor.defaultMarker;
    }
  }

  static Color colorForTagId(Object? tagId) { //Attempted to match the Bitmap descriptor colors
    final id = _coerceInt(tagId);
    switch (id) {
      case greenway:
      case park:
        return  Color.fromARGB(255, 16, 175, 122);
      case shopping:
        return  Color(0xFFFF007F);
      case eating:
        return  Color(0xFFFF8000);
      case placeOfWorship:
        return  Color(0xFF8000FF);
      default:
        return Colors.grey;
    }
  }

  static int? _coerceInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }
}

