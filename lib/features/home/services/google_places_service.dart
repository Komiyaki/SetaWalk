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
}

class GooglePlacesException implements Exception {
  final String message;

  const GooglePlacesException(this.message);

  @override
  String toString() => message;
}
