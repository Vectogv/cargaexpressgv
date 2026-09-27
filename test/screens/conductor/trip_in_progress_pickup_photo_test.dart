import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:cargaexpress/models/trip.dart';
import 'package:cargaexpress/screens/conductor/trip_in_progress_screen.dart';

import '../../helpers/fake_api.dart';

/// "Foto de la carga" (POST /api/trips/:id/pickup-photo): evidencia opcional
/// que el conductor puede subir sólo entre que llega al origen y antes de
/// llegar al destino (conductor_llegada, en_curso) — igual que la foto de
/// entrega, no bloquea el flujo.
void main() {
  http.Response backend(http.Request req) {
    final p = req.url.path;
    if (p == '/api/config/cliente') return jsonResp({'radioCierreKm': 1, 'confirmacionTimeoutMin': 15});
    return jsonResp({});
  }

  Trip viaje(String estado) => Trip.fromJson({
        'id': '5',
        'estado': estado,
        'origen': {'direccion': 'Parque Caldas', 'lat': 2.44188, 'lng': -76.60631},
        'destino': {'direccion': 'Centro Comercial Campanario', 'lat': 2.46129, 'lng': -76.5915},
        'cliente': {'id': 2, 'nombre': 'Ana Pérez', 'telefono': '3001110001'},
        'precioFinal': 17000,
      });

  void pantalla(WidgetTester tester) {
    tester.view.physicalSize = const Size(1440, 3200);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  Future<void> abrir(WidgetTester tester, String estado) async {
    await tester.pumpWidget(MaterialApp(home: TripInProgressScreen(trip: viaje(estado))));
    await avanzar(tester, 1);
  }

  Future<void> cerrar(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 2));
  }

  testWidgets('conductor_llegada: muestra el botón "Foto de la carga"', (tester) async {
    pantalla(tester);
    await conApiFalsa(backend, () async {
      await abrir(tester, 'conductor_llegada');
      expect(find.text('Foto de la carga'), findsOneWidget);
      await cerrar(tester);
    });
  });

  testWidgets('en_curso: muestra el botón "Foto de la carga" junto con el de entrega', (tester) async {
    pantalla(tester);
    await conApiFalsa(backend, () async {
      await abrir(tester, 'en_curso');
      expect(find.text('Foto de la carga'), findsOneWidget);
      expect(find.text('Tomar foto de entrega'), findsOneWidget);
      await cerrar(tester);
    });
  });

  testWidgets('aceptado y conductor_en_camino: sin botón, todavía no llega al origen', (tester) async {
    pantalla(tester);
    await conApiFalsa(backend, () async {
      await abrir(tester, 'aceptado');
      expect(find.text('Foto de la carga'), findsNothing);
      await cerrar(tester);

      await abrir(tester, 'conductor_en_camino');
      expect(find.text('Foto de la carga'), findsNothing);
      await cerrar(tester);
    });
  });

  testWidgets('entregado: sin botón, ya no sirve como evidencia de recogida', (tester) async {
    pantalla(tester);
    await conApiFalsa(backend, () async {
      await abrir(tester, 'entregado');
      expect(find.text('Foto de la carga'), findsNothing);
      await cerrar(tester);
    });
  });
}
