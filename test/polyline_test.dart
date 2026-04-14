import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:setawalk/features/home/models/polyline.dart';

void main() {
  const List<List<double>> testCoordinates = [ //polyline test with the coords
    [35.642533, 139.670354],
    [35.6424108, 139.6709242],
    [35.6424038, 139.67096],
    [35.6423281, 139.6714336],
    [35.6422833, 139.6716585],
    [35.6422186, 139.671915],
    [35.6422079, 139.6719575],
    [35.6420693, 139.6723126],
    [35.6420096, 139.6724609],
    [35.6419477, 139.6726095],
    [35.6419301, 139.6726638],
    [35.64201, 139.6727139],
    [35.6420898, 139.6729481],
    [35.6421013, 139.6729818],
    [35.6421105, 139.673009],
    [35.6421218, 139.6730421],
    [35.641904, 139.6731249],
    [35.6420585, 139.6734994],
  ];

  test('LatLng.fromJson parses coordinate pair', () {
    final jsonPair = [35.642533, 139.670354];
    final latLng = LatLng.fromJson(jsonPair);

    expect(latLng, const LatLng(35.642533, 139.670354));
  });

  test('createPolylineFromJson returns a Polyline with expected points', () {
    final jsonString = jsonEncode(testCoordinates);
    final polyline =
        MapDataProcessor.createPolylineFromJson(jsonString, 'test-id');

    expect(polyline.polylineId, 'test-id');
    expect(polyline.points, hasLength(18));
    expect(polyline.points.first, const LatLng(35.642533, 139.670354));
    expect(polyline.points.last, const LatLng(35.6420585, 139.6734994));
  });

  test('verifies all coordinates are parsed correctly', () {
    final jsonString = jsonEncode(testCoordinates);
    final polyline =
        MapDataProcessor.createPolylineFromJson(jsonString, 'test-id');

    for (int i = 0; i < testCoordinates.length; i++) {
      expect(
        polyline.points[i],
        LatLng(testCoordinates[i][0], testCoordinates[i][1]),
      );
    }
  });
}
