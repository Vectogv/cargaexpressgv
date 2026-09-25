import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:cargaexpress/models/trip.dart';
import 'package:cargaexpress/screens/conductor/trip_in_progress_screen.dart';
import 'package:cargaexpress/services/notification_service.dart';

import '../../helpers/fake_api.dart';

/// Salida de la pantalla del viaje del conductor. Al cancelar llegan dos
/// órdenes de salir casi a la vez (respuesta del POST /cancel y socket
/// `trip:cancelled`); el segundo `pop` quitaba el inicio y dejaba la app en
/// negro (viaje 28 en producción).
void main() {
  http.Response backend(http.Request req) {
    final p = req.url.path;
    if (p == '/api/config/cliente') return jsonResp({'radioCierreKm': 1, 'confirmacionTimeoutMin': 15});
    if (p.endsWith('/cancel')) return jsonResp({'id': '5', 'estado': 'cancelado'});
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

  Future<void> cerrar(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 2));
  }

  /// Inicio del conductor con la pantalla del viaje encima (como en la app).
  Future<void> abrirSobreInicio(WidgetTester tester, String estado) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.push(ctx, MaterialPageRoute(
                builder: (_) => TripInProgressScreen(trip: viaje(estado)),
              )),
              child: const Text('Inicio conductor'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Inicio conductor'));
    await avanzar(tester, 1);
    expect(find.byType(TripInProgressScreen), findsOneWidget);
  }

  /// Aviso `trip:cancelled` del backend (llega a la pantalla vía NotificationService).
  void cancelado() {
    NotificationService.instance.simularEventoParaTest('trip:cancelled', {
      'id': '5',
      'canceladoPor': 'cliente',
      'motivo': 'Ya no lo necesito',
    });
  }

  testWidgets('dos avisos de cancelación seguidos vuelven al inicio una sola vez (sin pantalla en negro)', (tester) async {
    pantalla(tester);
    await conApiFalsa(backend, () async {
      await abrirSobreInicio(tester, 'aceptado');

      cancelado();
      cancelado();
      await avanzar(tester, 1);

      expect(find.byType(TripInProgressScreen), findsNothing);
      expect(find.text('Inicio conductor'), findsOneWidget);
      expect(find.text('El cliente canceló el viaje: Ya no lo necesito'), findsOneWidget);
      await cerrar(tester);
    });
  });

  testWidgets('el conductor cancela y el socket confirma: vuelve al inicio y se avisa al cliente', (tester) async {
    pantalla(tester);
    final log = <http.Request>[];
    await conApiFalsa(backend, () async {
      await abrirSobreInicio(tester, 'aceptado');

      await tester.tap(find.text('Cancelar'));
      await avanzar(tester, 1);
      expect(find.text('Motivo de cancelación:'), findsOneWidget);
      await tester.tap(find.text('Problema con el cliente'));
      await avanzar(tester, 0.5);
      await tester.enterText(find.byType(TextField).last, 'Llamé tres veces y no contesta');
      await avanzar(tester, 0.5);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Cancelar viaje'));
      await avanzar(tester, 0.3);
      // El backend avisa por socket mientras la pantalla aún se está cerrando.
      cancelado();
      await avanzar(tester, 1);

      expect(log.where((r) => r.method == 'POST' && r.url.path == '/api/trips/5/cancel'), hasLength(1));
      expect(find.byType(TripInProgressScreen), findsNothing);
      expect(find.text('Inicio conductor'), findsOneWidget);
      await cerrar(tester);
    }, log: log);
  });

  testWidgets('como raíz (sin inicio debajo) la cancelación deja "No hay viaje activo", no una pantalla vacía', (tester) async {
    pantalla(tester);
    await conApiFalsa(backend, () async {
      await tester.pumpWidget(MaterialApp(home: TripInProgressScreen(trip: viaje('conductor_en_camino'))));
      await avanzar(tester, 1);

      cancelado();
      cancelado();
      await avanzar(tester, 1);

      expect(find.text('No hay viaje activo'), findsOneWidget);
      await cerrar(tester);
    });
  });
}
