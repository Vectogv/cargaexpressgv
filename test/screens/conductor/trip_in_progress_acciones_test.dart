import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:cargaexpress/models/trip.dart';
import 'package:cargaexpress/screens/conductor/esperando_confirmacion_cliente.dart';
import 'package:cargaexpress/screens/conductor/trip_in_progress_screen.dart';

import '../../helpers/fake_api.dart';

/// Pantalla del conductor durante el viaje: un solo mapa con un panel por
/// estado y la acción principal que corresponde a cada transición del backend
/// (confirm-arrival, confirm-pickup, start-trip, complete).
void main() {
  http.Response backend(http.Request req) {
    final p = req.url.path;
    if (p.endsWith('/confirm-arrival')) return jsonResp({'id': '5', 'estado': 'conductor_en_camino'});
    if (p.endsWith('/confirm-pickup')) return jsonResp({'id': '5', 'estado': 'conductor_llegada'});
    if (p.endsWith('/start-trip')) return jsonResp({'id': '5', 'estado': 'en_curso'});
    if (p == '/api/config/cliente') return jsonResp({'radioCierreKm': 1, 'confirmacionTimeoutMin': 15});
    return jsonResp({});
  }

  Trip viaje(String estado) => Trip.fromJson({
        'id': '5',
        'estado': estado,
        'origen': {'direccion': 'Parque Caldas, Calle 5 # 6-00', 'lat': 2.44188, 'lng': -76.60631},
        'destino': {'direccion': 'Centro Comercial Campanario', 'lat': 2.46129, 'lng': -76.5915},
        'cliente': {'id': 2, 'nombre': 'Ana Pérez', 'telefono': '3001110001', 'calificacion': 4.5},
        'carga': 'Muebles',
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

  ElevatedButton botonPrincipal(WidgetTester tester, String texto) =>
      tester.widget<ElevatedButton>(find.ancestor(of: find.text(texto), matching: find.byType(ElevatedButton)));

  testWidgets('aceptado: un solo mapa, datos del viaje y "Voy en camino al origen" llama a confirm-arrival', (tester) async {
    pantalla(tester);
    final log = <http.Request>[];
    await conApiFalsa(backend, () async {
      await abrir(tester, 'aceptado');

      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.text('Conduce al punto de recogida'), findsOneWidget);
      expect(find.text('Ana Pérez'), findsOneWidget);
      expect(find.text('4.5'), findsOneWidget);
      expect(find.text('Parque Caldas, Calle 5 # 6-00'), findsOneWidget);
      expect(find.text('Centro Comercial Campanario'), findsOneWidget);
      expect(find.text(r'$17.000'), findsOneWidget);
      expect(find.text('Muebles'), findsOneWidget);
      expect(find.text('Aceptado'), findsOneWidget);
      // Sin GPS en el test: se dice claramente.
      expect(find.text('Buscando señal GPS…'), findsOneWidget);
      expect(botonPrincipal(tester, 'Voy en camino al origen').onPressed, isNotNull);

      await tester.tap(find.text('Voy en camino al origen'));
      await avanzar(tester, 1);

      expect(log.where((r) => r.method == 'POST' && r.url.path == '/api/trips/5/confirm-arrival'), hasLength(1));
      // Pasa al siguiente estado con su propia acción.
      expect(find.text('En camino al origen'), findsOneWidget);
      expect(find.text('Llegué al origen'), findsOneWidget);
      expect(find.text('Voy en camino al origen'), findsNothing);
      await cerrar(tester);
    }, log: log);
  });

  testWidgets('conductor_en_camino sin GPS: se avisa que el servidor comprobará la ubicación y "Llegué al origen" llama a confirm-pickup', (tester) async {
    pantalla(tester);
    final log = <http.Request>[];
    await conApiFalsa(backend, () async {
      await abrir(tester, 'conductor_en_camino');

      expect(find.textContaining('Sin señal GPS todavía'), findsOneWidget);
      expect(botonPrincipal(tester, 'Llegué al origen').onPressed, isNotNull);

      await tester.tap(find.text('Llegué al origen'));
      await avanzar(tester, 1);

      expect(log.where((r) => r.method == 'POST' && r.url.path == '/api/trips/5/confirm-pickup'), hasLength(1));
      expect(find.text('Estás en el origen'), findsOneWidget);
      expect(find.text('Iniciar viaje'), findsOneWidget);
      await cerrar(tester);
    }, log: log);
  });

  testWidgets('conductor_llegada: "Iniciar viaje" llama a start-trip y pasa a en curso con foto y finalizar', (tester) async {
    pantalla(tester);
    final log = <http.Request>[];
    await conApiFalsa(backend, () async {
      await abrir(tester, 'conductor_llegada');

      await tester.tap(find.text('Iniciar viaje'));
      await avanzar(tester, 1);

      expect(log.where((r) => r.method == 'POST' && r.url.path == '/api/trips/5/start-trip'), hasLength(1));
      expect(find.text('Viaje en curso'), findsWidgets);
      expect(find.text('Tomar foto de entrega'), findsOneWidget);
      expect(find.text('Finalizar viaje'), findsOneWidget);
      // Sin GPS el cierre pedirá justificación: se anticipa al conductor.
      expect(find.textContaining('se te pedirá una justificación'), findsOneWidget);
      await cerrar(tester);
    }, log: log);
  });

  testWidgets('el error del backend al confirmar la llegada se muestra y el estado no cambia', (tester) async {
    pantalla(tester);
    await conApiFalsa((req) {
      if (req.url.path.endsWith('/confirm-pickup')) {
        return errorResp(422, 'No puedes marcar la recogida: estás a 3.20 km del punto de origen.', 'FUERA_DE_RANGO_ORIGEN');
      }
      return backend(req);
    }, () async {
      await abrir(tester, 'conductor_en_camino');
      await tester.tap(find.text('Llegué al origen'));
      await avanzar(tester, 1);

      expect(find.textContaining('3.20 km del punto de origen'), findsOneWidget);
      expect(find.text('Llegué al origen'), findsOneWidget);
      expect(find.text('Iniciar viaje'), findsNothing);
      await cerrar(tester);
    });
  });

  testWidgets('pendiente_confirmacion: sin acción principal, sólo la espera del cliente', (tester) async {
    pantalla(tester);
    await conApiFalsa(backend, () async {
      await abrir(tester, 'pendiente_confirmacion');

      expect(find.byType(EsperandoConfirmacionCliente), findsOneWidget);
      expect(find.text('Esperando al cliente'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.text('Finalizar viaje'), findsNothing);
      await cerrar(tester);
    });
  });

  testWidgets('la barra inferior respeta el área segura del sistema', (tester) async {
    pantalla(tester);
    tester.view.padding = const FakeViewPadding(bottom: 120);
    await conApiFalsa(backend, () async {
      await abrir(tester, 'aceptado');
      final sos = tester.getBottomLeft(find.text('SOS'));
      final alto = tester.view.physicalSize.height / tester.view.devicePixelRatio;
      // 120 px físicos = 40 dp de barra del sistema: el texto queda por encima.
      expect(sos.dy, lessThanOrEqualTo(alto - 40));
      await cerrar(tester);
    });
  });
}
