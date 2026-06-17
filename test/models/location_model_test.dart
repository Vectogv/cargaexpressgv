import 'package:flutter_test/flutter_test.dart';
import 'package:cargaexpress/models/location_model.dart';

void main() {
  group('LocationModel', () {
    const testLat = 19.4326;
    const testLng = -99.1332;
    const testDireccion = 'Av. Reforma 123, CDMX';

    final completeJson = {
      'lat': testLat.toString(),
      'lng': testLng.toString(),
      'direccion': testDireccion,
    };

    group('fromJson', () {
      test('creates model from complete JSON', () {
        final model = LocationModel.fromJson(completeJson);
        expect(model.lat, testLat);
        expect(model.lng, testLng);
        expect(model.direccion, testDireccion);
      });

      test('handles empty direccion', () {
        final json = {
          'lat': '0.0',
          'lng': '0.0',
          'direccion': null,
        };
        final model = LocationModel.fromJson(json);
        expect(model.direccion, '');
      });

      test('parses numeric lat/lng as strings', () {
        final json = {
          'lat': '19.5',
          'lng': '-99.2',
          'direccion': 'Test',
        };
        final model = LocationModel.fromJson(json);
        expect(model.lat, 19.5);
        expect(model.lng, -99.2);
      });
    });

    group('toJson', () {
      test('returns correct map', () {
        final model = LocationModel(lat: testLat, lng: testLng, direccion: testDireccion);
        final json = model.toJson();
        expect(json['lat'], testLat);
        expect(json['lng'], testLng);
        expect(json['direccion'], testDireccion);
      });
    });

    group('copyWith', () {
      test('returns same instance when no args', () {
        final a = LocationModel(lat: 1.0, lng: 2.0, direccion: 'A');
        final b = a.copyWith();
        expect(b.lat, 1.0);
        expect(b.lng, 2.0);
        expect(b.direccion, 'A');
      });

      test('overrides only specified field', () {
        final a = LocationModel(lat: 1.0, lng: 2.0, direccion: 'A');
        final b = a.copyWith(lat: 99.9);
        expect(b.lat, 99.9);
        expect(b.lng, 2.0);
        expect(b.direccion, 'A');
      });
    });
  });
}
