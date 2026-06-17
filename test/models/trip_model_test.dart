import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cargaexpress/models/trip_model.dart';
import 'package:cargaexpress/models/location_model.dart';
import 'package:cargaexpress/models/user_model.dart';

void main() {
  group('TripModel', () {
    final completeJson = {
      '_id': 'trip123',
      'estado': 'pendiente',
      'origen': {
        'lat': '19.4326',
        'lng': '-99.1332',
        'direccion': 'Origen',
      },
      'destino': {
        'lat': '19.4278',
        'lng': '-99.1417',
        'direccion': 'Destino',
      },
      'carga': 'Caja de herramientas',
      'descripcion': 'Entrega urgente',
      'precioEstimado': 150.50,
      'precioFinal': null,
      'distancia': 5.2,
      'tiempoEstimado': 15,
      'cliente': {
        '_id': 'cli1',
        'nombre': 'Cliente',
        'email': 'cli@test.com',
      },
      'conductor': null,
      'createdAt': '2025-01-01T00:00:00Z',
      'updatedAt': '2025-01-01T00:00:00Z',
    };

    group('fromJson', () {
      test('creates model from complete JSON', () {
        final model = TripModel.fromJson(completeJson);
        expect(model.id, 'trip123');
        expect(model.estado, 'pendiente');
        expect(model.origen, isA<LocationModel>());
        expect(model.origen!.direccion, 'Origen');
        expect(model.destino!.direccion, 'Destino');
        expect(model.carga, 'Caja de herramientas');
        expect(model.precioEstimado, 150.50);
        expect(model.precioFinal, isNull);
        expect(model.distancia, 5.2);
        expect(model.tiempoEstimado, 15);
        expect(model.cliente, isA<UserModel>());
        expect(model.cliente!.nombre, 'Cliente');
        expect(model.conductor, isNull);
      });

      test('handles null nested objects', () {
        final json = {'_id': 't1', 'origen': null, 'destino': null, 'cliente': null, 'conductor': null};
        final model = TripModel.fromJson(json);
        expect(model.origen, isNull);
        expect(model.destino, isNull);
        expect(model.cliente, isNull);
        expect(model.conductor, isNull);
      });

      test('parses precioEstimado from int', () {
        final json = {'_id': 't1', 'precioEstimado': 200};
        expect(TripModel.fromJson(json).precioEstimado, 200);
      });

      test('parses precioEstimado from string', () {
        final json = {'_id': 't1', 'precioEstimado': '300.75'};
        expect(TripModel.fromJson(json).precioEstimado, 300.75);
      });
    });

    group('toJson', () {
      test('serializes nested objects correctly', () {
        final model = TripModel.fromJson(completeJson);
        final json = model.toJson();
        expect(json['_id'], 'trip123');
        expect(json['origen'], isA<Map>());
        expect(json['origen']['direccion'], 'Origen');
        expect(json['cliente']['nombre'], 'Cliente');
        expect(json['conductor'], isNull);
      });
    });

    group('isActive', () {
      test('is true for pendiente', () {
        final t = TripModel(id: '1', estado: 'pendiente');
        expect(t.isActive, isTrue);
      });

      test('is true for aceptado', () {
        final t = TripModel(id: '1', estado: 'aceptado');
        expect(t.isActive, isTrue);
      });

      test('is true for en_curso', () {
        final t = TripModel(id: '1', estado: 'en_curso');
        expect(t.isActive, isTrue);
      });

      test('is false for cancelado', () {
        final t = TripModel(id: '1', estado: 'cancelado');
        expect(t.isActive, isFalse);
      });

      test('is false for finalizado', () {
        final t = TripModel(id: '1', estado: 'finalizado');
        expect(t.isActive, isFalse);
      });

      test('is false for completado', () {
        final t = TripModel(id: '1', estado: 'completado');
        expect(t.isActive, isFalse);
      });

      test('is true for unknown state', () {
        final t = TripModel(id: '1', estado: 'unknown');
        expect(t.isActive, isTrue);
      });
    });

    group('estadoLabel', () {
      test('returns correct label for each state', () {
        expect(TripModel(id: '1', estado: 'pendiente').estadoLabel, 'Pendiente');
        expect(TripModel(id: '1', estado: 'aceptado').estadoLabel, 'Aceptado');
        expect(TripModel(id: '1', estado: 'en_curso').estadoLabel, 'En curso');
        expect(TripModel(id: '1', estado: 'completado').estadoLabel, 'Completado');
        expect(TripModel(id: '1', estado: 'finalizado').estadoLabel, 'Finalizado');
        expect(TripModel(id: '1', estado: 'cancelado').estadoLabel, 'Cancelado');
      });

      test('returns estado value for unknown state', () {
        expect(TripModel(id: '1', estado: 'custom').estadoLabel, 'custom');
      });

      test('returns Desconocido for null estado', () {
        expect(TripModel(id: '1').estadoLabel, 'Desconocido');
      });
    });

    group('estadoColor', () {
      test('returns correct color for each state', () {
        expect(TripModel(id: '1', estado: 'pendiente').estadoColor, Colors.orange);
        expect(TripModel(id: '1', estado: 'aceptado').estadoColor, Colors.blue);
        expect(TripModel(id: '1', estado: 'en_curso').estadoColor, Colors.green);
        expect(TripModel(id: '1', estado: 'completado').estadoColor, Colors.teal);
        expect(TripModel(id: '1', estado: 'finalizado').estadoColor, Colors.grey);
        expect(TripModel(id: '1', estado: 'cancelado').estadoColor, Colors.red);
      });

      test('returns grey for null estado', () {
        expect(TripModel(id: '1').estadoColor, Colors.grey);
      });
    });

    group('copyWith', () {
      test('overrides nested fields with fresh objects', () {
        final a = TripModel(id: '1', estado: 'pendiente',
          origen: LocationModel(lat: 1.0, lng: 2.0, direccion: 'A'));
        final b = a.copyWith(estado: 'aceptado');
        expect(b.id, '1');
        expect(b.estado, 'aceptado');
        expect(b.origen!.direccion, 'A');
      });
    });
  });
}
