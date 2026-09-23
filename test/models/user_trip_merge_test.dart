import 'package:flutter_test/flutter_test.dart';
import 'package:cargaexpress/models/trip.dart';
import 'package:cargaexpress/models/user.dart';

void main() {
  group('User.fromJson', () {
    test('usa `id` cuando falta `_id` (payload de socket)', () {
      final u = User.fromJson({'id': '42', 'nombre': 'Carlos'});
      expect(u.id, '42');
      expect(u.nombre, 'Carlos');
    });

    test('convierte un id numérico a String', () {
      final u = User.fromJson({'id': 7});
      expect(u.id, '7');
    });

    test('no lanza si no hay ningún id', () {
      final u = User.fromJson({'nombre': 'Sin id'});
      expect(u.id, '');
    });

    test('Trip con conductor anidado sin `_id` no lanza', () {
      final trip = Trip.fromJson({
        'id': '10',
        'estado': 'aceptado',
        'conductor': {'id': '5', 'nombre': 'Ana', 'placa': 'ABC123'},
      });
      expect(trip.conductor?.id, '5');
      expect(trip.conductor?.nombre, 'Ana');
    });
  });

  group('Trip.mergeSocketPayload', () {
    final base = Trip(
      id: '10',
      estado: 'buscando_conductor',
      conductor: User(id: 'c1', nombre: 'Ana', telefono: '300', calificacion: 4.8),
    ).toJson();

    test('un conductor parcial no pisa los datos completos', () {
      final merged = Trip.mergeSocketPayload(base, {
        'id': 10,
        'estado': 'aceptado',
        'conductor': {'id': 'c1', 'placa': 'XYZ'},
      });
      final trip = Trip.fromJson(merged);
      expect(trip.estado, 'aceptado');
      expect(trip.id, '10');
      expect(trip.conductor?.id, 'c1');
      expect(trip.conductor?.nombre, 'Ana');
      expect(trip.conductor?.telefono, '300');
    });

    test('valores null entrantes no borran datos existentes', () {
      final merged = Trip.mergeSocketPayload(base, {
        'estado': 'en_curso',
        'conductor': null,
      });
      final trip = Trip.fromJson(merged);
      expect(trip.estado, 'en_curso');
      expect(trip.conductor?.nombre, 'Ana');
    });

    test('conductor nuevo sin `_id` toma el `id`', () {
      final merged = Trip.mergeSocketPayload(
        <String, dynamic>{'_id': '10'},
        {
          'estado': 'aceptado',
          'conductor': {'id': '99', 'nombre': 'Luis'},
        },
      );
      final trip = Trip.fromJson(merged);
      expect(trip.conductor?.id, '99');
    });
  });
}
