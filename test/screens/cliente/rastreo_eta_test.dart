import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cargaexpress/contracts/trip_status.dart';
import 'package:cargaexpress/screens/cliente/rastreo_screen.dart';

import '../../helpers/fake_api.dart';

void main() {
  testWidgets('el seguimiento no muestra "5 min" inventado ni distancia desde 0,0', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa((req) {
      if (req.url.path == '/api/trips/active') {
        return jsonResp({
          '_id': 't1',
          'estado': 'aceptado',
          'origen': {'lat': 4.6, 'lng': -74.1, 'direccion': 'Origen'},
          'destino': {'lat': 4.7, 'lng': -74.0, 'direccion': 'Destino'},
          'conductor': {'nombre': 'Carlos'},
        });
      }
      return jsonResp({});
    }, () async {
      await tester.pumpWidget(const MaterialApp(home: RastreoScreen()));
      await avanzar(tester);
      expect(find.text('Conductor asignado'), findsOneWidget);
      expect(find.text('5 min'), findsNothing);
      expect(find.byIcon(Icons.access_time), findsNothing);
      expect(find.text('--'), findsOneWidget);
    });
  });

  testWidgets('con el conductor en camino el chat está disponible', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa((req) {
      if (req.url.path == '/api/trips/active') {
        return jsonResp({
          '_id': 't1',
          'estado': 'conductor_en_camino',
          'origen': {'lat': 4.6, 'lng': -74.1, 'direccion': 'Origen'},
          'conductor': {'nombre': 'Carlos'},
        });
      }
      return jsonResp({});
    }, () async {
      await tester.pumpWidget(const MaterialApp(home: RastreoScreen()));
      await avanzar(tester);
      expect(find.text('Chat'), findsOneWidget);
    });
  });

  test('sin datos de ETA no se muestra nada (antes "5 min" fijo)', () {
    expect(etaRecogida(status: TripStatus.aceptado), isNull);
    expect(etaRecogida(status: TripStatus.aceptado, distanciaKm: double.infinity), isNull);
  });

  test('con la posición del conductor: 30 km/h, igual que el backend', () {
    expect(etaRecogida(status: TripStatus.aceptado, distanciaKm: 5), '10 min');
    expect(etaRecogida(status: TripStatus.enCamino, distanciaKm: 0.1), '1 min');
  });

  test('sin posición en vivo usa el tiempo estimado del backend', () {
    expect(etaRecogida(status: TripStatus.aceptado, tiempoEstimado: 12), '12 min');
    expect(etaRecogida(status: TripStatus.aceptado, tiempoEstimado: 0), isNull);
  });

  test('después de la recogida no hay ETA de recogida', () {
    expect(etaRecogida(status: TripStatus.enCurso, distanciaKm: 5, tiempoEstimado: 12), isNull);
    expect(etaRecogida(status: TripStatus.llegada, distanciaKm: 0.01), isNull);
  });
}
