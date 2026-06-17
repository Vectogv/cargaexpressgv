import 'package:flutter_test/flutter_test.dart';
import 'package:cargaexpress/models/sos_alert_model.dart';

void main() {
  group('SosAlertModel', () {
    final completeJson = {
      'id': 'sos123',
      'driverId': 'drv456',
      'tripId': 'trip789',
      'latitude': 19.4326,
      'longitude': -99.1332,
      'speed': 45.5,
      'timestamp': '2025-01-01T12:00:00Z',
      'status': 'activa',
    };

    group('fromJson', () {
      test('creates model from complete JSON', () {
        final model = SosAlertModel.fromJson(completeJson);
        expect(model.id, 'sos123');
        expect(model.driverId, 'drv456');
        expect(model.tripId, 'trip789');
        expect(model.latitude, 19.4326);
        expect(model.longitude, -99.1332);
        expect(model.speed, 45.5);
        expect(model.status, 'activa');
      });

      test('handles driverId as number', () {
        final json = {
          'id': 's1',
          'driverId': 12345,
          'tripId': 67890,
        };
        final model = SosAlertModel.fromJson(json);
        expect(model.driverId, '12345');
        expect(model.tripId, '67890');
      });

      test('handles null latitude/longitude', () {
        final json = {'id': 's1'};
        final model = SosAlertModel.fromJson(json);
        expect(model.latitude, isNull);
        expect(model.longitude, isNull);
      });
    });

    group('toJson', () {
      test('serializes correctly', () {
        final model = SosAlertModel.fromJson(completeJson);
        final json = model.toJson();
        expect(json['id'], 'sos123');
        expect(json['latitude'], 19.4326);
        expect(json['status'], 'activa');
      });

      test('omits null id', () {
        final model = SosAlertModel(driverId: 'd1');
        final json = model.toJson();
        expect(json.containsKey('id'), isFalse);
      });
    });

    group('copyWith', () {
      test('overrides specified fields', () {
        final a = SosAlertModel(id: '1', status: 'activa');
        final b = a.copyWith(status: 'resuelta');
        expect(b.status, 'resuelta');
        expect(b.id, '1');
      });
    });
  });
}
