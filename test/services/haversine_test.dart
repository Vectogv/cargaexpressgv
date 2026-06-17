import 'dart:math';
import 'package:flutter_test/flutter_test.dart';

double haversine(double lat1, double lon1, double lat2, double lon2) {
  const R = 6371.0;
  final dLat = _toRad(lat2 - lat1);
  final dLon = _toRad(lon2 - lon1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
  final c = 2 * asin(sqrt(a));
  return R * c;
}

double _toRad(double deg) => deg * pi / 180.0;

void main() {
  group('Haversine', () {
    test('distance between same point is 0', () {
      expect(haversine(19.4326, -99.1332, 19.4326, -99.1332), closeTo(0, 0.001));
    });

    test('CDMX - NYC ~3359 km', () {
      final d = haversine(19.4326, -99.1332, 40.7128, -74.0060);
      expect(d, closeTo(3359, 10));
    });

    test('CDMX - Madrid ~9068 km', () {
      final d = haversine(19.4326, -99.1332, 40.4168, -3.7038);
      expect(d, closeTo(9068, 10));
    });

    test('Madrid - NYC ~5774 km', () {
      final d = haversine(40.4168, -3.7038, 40.7128, -74.0060);
      expect(d, closeTo(5774, 10));
    });

    test('CDMX Sur - CDMX Centro ~5.5 km', () {
      final d = haversine(19.3900, -99.1400, 19.4326, -99.1332);
      expect(d, closeTo(4.8, 1));
    });

    test('distance is symmetric', () {
      final d1 = haversine(19.0, -99.0, 25.0, -100.0);
      final d2 = haversine(25.0, -100.0, 19.0, -99.0);
      expect(d1, closeTo(d2, 0.001));
    });

    test('works with negative coordinates (southern hemisphere)', () {
      final d = haversine(-33.8688, 151.2093, -37.8136, 144.9631);
      expect(d, closeTo(713, 10));
    });

    test('works across the equator', () {
      final d = haversine(0.0, 0.0, 10.0, 0.0);
      expect(d, closeTo(1109, 5));
    });
  });
}
