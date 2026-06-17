import 'package:flutter_test/flutter_test.dart';
import 'package:cargaexpress/models/offer_model.dart';

void main() {
  group('OfferModel', () {
    final completeJson = {
      '_id': 'offer123',
      'tripId': 'trip456',
      'conductor': {
        '_id': 'cond1',
        'nombre': 'Carlos',
        'calificacion': 4.8,
      },
      'monto': 250.0,
      'placa': 'ABC-1234',
      'estado': 'pendiente',
      'createdAt': '2025-01-01T00:00:00Z',
    };

    group('fromJson', () {
      test('creates model from complete JSON', () {
        final model = OfferModel.fromJson(completeJson);
        expect(model.id, 'offer123');
        expect(model.tripId, 'trip456');
        expect(model.conductor, isNotNull);
        expect(model.conductor!.nombre, 'Carlos');
        expect(model.monto, 250.0);
        expect(model.placa, 'ABC-1234');
        expect(model.estado, 'pendiente');
      });

      test('handles viaje key for tripId', () {
        final json = {'_id': 'o1', 'viaje': 't1'};
        final model = OfferModel.fromJson(json);
        expect(model.tripId, 't1');
      });

      test('handles null conductor', () {
        final json = {'_id': 'o1', 'tripId': 't1', 'conductor': null};
        final model = OfferModel.fromJson(json);
        expect(model.conductor, isNull);
      });

      test('parses monto from string', () {
        final json = {'_id': 'o1', 'tripId': 't1', 'monto': '150.50'};
        expect(OfferModel.fromJson(json).monto, 150.50);
      });
    });

    group('toJson', () {
      test('serializes nested objects', () {
        final model = OfferModel.fromJson(completeJson);
        final json = model.toJson();
        expect(json['_id'], 'offer123');
        expect(json['conductor'], isA<Map>());
        expect(json['conductor']['nombre'], 'Carlos');
      });
    });

    group('copyWith', () {
      test('overrides specified fields', () {
        final a = OfferModel(id: '1', tripId: 't1', monto: 100);
        final b = a.copyWith(monto: 200);
        expect(b.monto, 200);
        expect(b.tripId, 't1');
      });
    });
  });
}
