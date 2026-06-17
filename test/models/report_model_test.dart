import 'package:flutter_test/flutter_test.dart';
import 'package:cargaexpress/models/report_model.dart';

void main() {
  group('ReportModel', () {
    final completeJson = {
      'id': 'rpt123',
      'tipo': 'cliente_agresivo',
      'descripcion': 'El cliente fue agresivo durante el viaje',
      'tripId': 'trip456',
      'userId': 'user789',
      'targetId': 'target111',
      'status': 'pendiente',
      'fotos': ['foto1.jpg', 'foto2.jpg'],
      'createdAt': '2025-01-01T00:00:00Z',
    };

    group('fromJson', () {
      test('creates model from complete JSON', () {
        final model = ReportModel.fromJson(completeJson);
        expect(model.id, 'rpt123');
        expect(model.tipo, 'cliente_agresivo');
        expect(model.descripcion, 'El cliente fue agresivo durante el viaje');
        expect(model.tripId, 'trip456');
        expect(model.status, 'pendiente');
        expect(model.fotos, ['foto1.jpg', 'foto2.jpg']);
      });

      test('handles tripId as number', () {
        final json = {'id': 'r1', 'tripId': 12345};
        expect(ReportModel.fromJson(json).tripId, '12345');
      });

      test('handles null fotos', () {
        final json = {'id': 'r1', 'fotos': null};
        expect(ReportModel.fromJson(json).fotos, isNull);
      });

      test('handles empty fotos', () {
        final json = {'id': 'r1', 'fotos': []};
        expect(ReportModel.fromJson(json).fotos, isEmpty);
      });
    });

    group('toJson', () {
      test('serializes correctly', () {
        final model = ReportModel.fromJson(completeJson);
        final json = model.toJson();
        expect(json['tipo'], 'cliente_agresivo');
        expect(json['fotos'], ['foto1.jpg', 'foto2.jpg']);
      });

      test('omits null id', () {
        final model = ReportModel(tipo: 'fraude');
        final json = model.toJson();
        expect(json.containsKey('id'), isFalse);
      });
    });

    group('copyWith', () {
      test('overrides specified fields', () {
        final a = ReportModel(id: '1', status: 'pendiente');
        final b = a.copyWith(status: 'resuelto');
        expect(b.status, 'resuelto');
        expect(b.id, '1');
      });
    });
  });
}
