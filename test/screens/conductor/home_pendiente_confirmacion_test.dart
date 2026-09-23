import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:cargaexpress/screens/conductor/esperando_confirmacion_cliente.dart';
import 'package:cargaexpress/screens/conductor/home_screen.dart';
import 'package:cargaexpress/screens/conductor/trip_in_progress_screen.dart';

import '../../helpers/fake_api.dart';

void main() {
  Map<String, dynamic> viajeActivo = {};

  http.Response backend(http.Request req) {
    final p = req.url.path;
    if (p == '/api/users/profile') {
      return jsonResp({'id': 1, 'nombre': 'Luis', 'conductor': {'estadoVerificacion': 'aprobado'}});
    }
    if (p == '/api/payment/debt') return jsonResp({'estadoCuenta': 'activa', 'montoDeuda': 0});
    if (p == '/api/trips/active') return jsonResp(viajeActivo);
    if (p == '/api/drivers/status') return jsonResp({'online': req.body.contains('true')});
    return jsonResp({});
  }

  Map<String, dynamic> viaje(String estado) => {
        'id': '5',
        'estado': estado,
        'origen': {'direccion': 'Calle 10 #5-20', 'lat': 4.6, 'lng': -74.0},
        'destino': {'direccion': 'Carrera 7 #80-15', 'lat': 4.7, 'lng': -74.1},
        'cliente': {'id': 2, 'nombre': 'Ana'},
        'precioEstimado': 60000,
      };

  /// La vista del viaje necesita más ancho con la fuente de test.
  void pantallaAncha(WidgetTester tester) {
    tester.view.physicalSize = const Size(2400, 3000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  Future<void> cerrar(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await avanzar(tester, 1);
    // Reintentos con espera de la vista del viaje (sin conexión real).
    await tester.pump(const Duration(minutes: 2));
  }

  testWidgets('al reiniciar restaura el viaje pendiente de confirmación y el conductor sigue pudiendo conectarse', (tester) async {
    pantallaAncha(tester);
    viajeActivo = viaje('pendiente_confirmacion');
    final log = <http.Request>[];
    await conApiFalsa(backend, () async {
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await avanzar(tester, 3);

      // Se abre el viaje en "Esperando que el cliente confirme".
      expect(find.byType(TripInProgressScreen), findsOneWidget);
      expect(find.byType(EsperandoConfirmacionCliente), findsOneWidget);

      // Esperar al cliente no lo deja "ocupado": se conecta igual.
      expect(log.where((r) => r.url.path == '/api/drivers/status' && r.body.contains('true')), isNotEmpty);

      // De vuelta en el inicio: el interruptor sigue disponible y en línea.
      Navigator.of(tester.element(find.byType(TripInProgressScreen))).pop();
      await avanzar(tester, 1);
      final interruptor = tester.widget<Switch>(find.byType(Switch));
      expect(interruptor.value, isTrue);
      expect(interruptor.onChanged, isNotNull);
      expect(find.text('Esperando confirmación del cliente'), findsOneWidget);
      await cerrar(tester);
    }, log: log);
  });

  testWidgets('un viaje realmente activo sigue ocupando al conductor (no se conecta a nuevos)', (tester) async {
    pantallaAncha(tester);
    viajeActivo = viaje('en_curso');
    final log = <http.Request>[];
    await conApiFalsa(backend, () async {
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await avanzar(tester, 3);
      expect(find.byType(TripInProgressScreen), findsOneWidget);
      expect(log.where((r) => r.url.path == '/api/drivers/status' && r.body.contains('true')), isEmpty);
      await cerrar(tester);
    }, log: log);
  });
}
