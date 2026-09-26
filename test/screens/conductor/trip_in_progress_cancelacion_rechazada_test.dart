import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cargaexpress/contracts/socket_events.dart';
import 'package:cargaexpress/models/trip.dart';
import 'package:cargaexpress/screens/conductor/trip_in_progress_screen.dart';
import 'package:cargaexpress/services/socket_service_client.dart';

import '../../helpers/fake_api.dart';

/// El admin rechaza la solicitud de cancelación que hizo el conductor
/// (`request-cancellation`, sólo posible en en_curso/llegada/sos): el
/// backend emite `trip:cancellation_rejected` y el viaje sigue activo.
void main() {
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

  testWidgets('muestra el aviso claro y el viaje sigue activo (no navega)', (tester) async {
    pantalla(tester);
    await conApiFalsa((req) {
      if (req.url.path == '/api/config/cliente') return jsonResp({'radioCierreKm': 1, 'confirmacionTimeoutMin': 15});
      return jsonResp({});
    }, () async {
      await tester.pumpWidget(MaterialApp(home: TripInProgressScreen(trip: viaje('en_curso'))));
      await avanzar(tester, 1);
      expect(find.byType(TripInProgressScreen), findsOneWidget);

      SocketServiceClient.instance.simularEventoParaTest(SocketEvents.tripCancellationRejected, {
        'id': '9',
        'viajeId': '5',
        'estado': 'rechazado',
        'motivo': 'El viaje ya casi termina',
      });
      await avanzar(tester, 1);

      expect(
        find.text('El administrador rechazó la cancelación. El viaje continúa. Motivo: El viaje ya casi termina.'),
        findsOneWidget,
      );
      expect(find.byType(TripInProgressScreen), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(minutes: 2));
    });
  });

  testWidgets('un evento de otro viaje (viajeId distinto) se ignora', (tester) async {
    pantalla(tester);
    await conApiFalsa((req) {
      if (req.url.path == '/api/config/cliente') return jsonResp({'radioCierreKm': 1, 'confirmacionTimeoutMin': 15});
      return jsonResp({});
    }, () async {
      await tester.pumpWidget(MaterialApp(home: TripInProgressScreen(trip: viaje('en_curso'))));
      await avanzar(tester, 1);

      SocketServiceClient.instance.simularEventoParaTest(SocketEvents.tripCancellationRejected, {
        'id': '9',
        'viajeId': 'otro-viaje',
        'estado': 'rechazado',
        'motivo': 'No debería verse',
      });
      await avanzar(tester, 1);

      expect(find.textContaining('rechazó la cancelación'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(minutes: 2));
    });
  });
}
