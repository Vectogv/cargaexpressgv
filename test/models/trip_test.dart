import 'package:flutter_test/flutter_test.dart';
import 'package:cargaexpress/models/trip.dart';
import 'package:cargaexpress/models/location_model.dart';

void main() {
  group('Trip Model', () {
    test('Debe parsear correctamente desde JSON', () {
      final json = {
        '_id': 'viaje_123',
        'estado': 'en_curso',
        'origen': {
          'direccion': 'Calle Principal 123',
          'lat': 10.0,
          'lng': -74.5,
        },
        'destino': {
          'direccion': 'Calle Secundaria 456',
          'lat': 10.5,
          'lng': -74.8,
        },
        'precioEstimado': 55000,
        'precioFinal': 60000,
      };

      final trip = Trip.fromJson(json);

      expect(trip.id, 'viaje_123');
      expect(trip.estado, 'en_curso');
      expect(trip.precioEstimado, 55000);
      expect(trip.precioFinal, 60000);
      expect(trip.origen?.direccion, 'Calle Principal 123');
      expect(trip.origen?.lat, 10.0);
      expect(trip.origen?.lng, -74.5);
      expect(trip.destino?.direccion, 'Calle Secundaria 456');
    });

    test('Debe serializar a JSON correctamente', () {
      final trip = Trip(
        id: 'viaje_456',
        estado: 'aceptado',
        origen: LocationModel(lat: 0.0, lng: 0.0, direccion: 'Origen Test'),
        destino: LocationModel(lat: 1.0, lng: 1.0, direccion: 'Destino Test'),
        precioEstimado: 100000,
      );

      final json = trip.toJson();

      expect(json['_id'], 'viaje_456');
      expect(json['estado'], 'aceptado');
      expect(json['precioEstimado'], 100000);
      expect((json['origen'] as Map<String, dynamic>)['direccion'], 'Origen Test');
      expect((json['origen'] as Map<String, dynamic>)['lat'], 0.0);
    });

    test('Debe manejar campos nulos correctamente', () {
      final json = {'_id': 'viaje_nulo'};

      final trip = Trip.fromJson(json);

      expect(trip.id, 'viaje_nulo');
      expect(trip.estado, isNull);
      expect(trip.origen, isNull);
      expect(trip.destino, isNull);
      expect(trip.cliente, isNull);
      expect(trip.conductor, isNull);
    });

    test('Debe parsear _id como id', () {
      final json = {'_id': 'backend_id_789', 'estado': 'pendiente'};
      final trip = Trip.fromJson(json);

      expect(trip.id, 'backend_id_789');
      expect(trip.toJson()['_id'], 'backend_id_789');
    });
  });
}
