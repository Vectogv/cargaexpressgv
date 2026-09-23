import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:cargaexpress/screens/conductor/oferta_aceptada_screen.dart';
import 'package:cargaexpress/screens/conductor/offers_screen.dart';
import 'package:cargaexpress/services/server_clock.dart';
import 'package:cargaexpress/services/socket_service_client.dart';

import '../../helpers/fake_api.dart';

void main() {
  late DateTime ahora;
  late List<Map<String, dynamic>> ofertas;
  late bool fallar;

  Map<String, dynamic> oferta(String id, String viajeId, int segundos, {int monto = 60000}) => {
        'id': id,
        'viajeId': viajeId,
        'monto': monto,
        'estado': 'pendiente',
        'expiresAt': ahora.add(Duration(seconds: segundos)).toIso8601String(),
        'createdAt': ahora.toIso8601String(),
        'viaje': {
          'origen': {'direccion': 'Calle 10 #5-20', 'lat': 4.6, 'lng': -74.0},
          'destino': {'direccion': 'Carrera 7 #80-15', 'lat': 4.7, 'lng': -74.1},
          'estado': 'buscando',
        },
      };

  http.Response backend(http.Request req) {
    final p = req.url.path;
    if (p == '/api/drivers/offers') {
      if (fallar) return errorResp(500, 'Error del servidor');
      return jsonResp(ofertas);
    }
    if (p == '/api/trips/active') return errorResp(404, 'Sin viaje');
    if (p.endsWith('/history')) return jsonResp({'data': []});
    if (p == '/api/trips/9') {
      return jsonResp({
        'id': '9',
        'estado': 'aceptado',
        'origen': {'direccion': 'Calle 10 #5-20'},
        'destino': {'direccion': 'Carrera 7 #80-15'},
        'cliente': {'nombre': 'Ana'},
      });
    }
    return jsonResp({});
  }

  setUp(() {
    ahora = DateTime.utc(2026, 9, 23, 15);
    ServerClock.ahoraLocal = () => ahora;
    ofertas = [oferta('31', '9', 25)];
    fallar = false;
  });
  tearDown(ServerClock.reiniciar);

  Future<void> abrir(WidgetTester tester) async {
    pantallaAlta(tester);
    await tester.pumpWidget(const MaterialApp(home: OffersScreen()));
    await avanzar(tester);
  }

  /// Avanza el reloj simulado y los timers [segundos].
  Future<void> pasar(WidgetTester tester, int segundos) async {
    for (var i = 0; i < segundos; i++) {
      ahora = ahora.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
    }
  }

  Future<void> cerrar(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await avanzar(tester);
  }

  testWidgets('muestra la oferta pendiente con ruta, monto y cuenta regresiva que al terminar la quita', (tester) async {
    await conApiFalsa(backend, () async {
      await abrir(tester);
      expect(find.text('Pendientes'), findsOneWidget);
      expect(find.text('Calle 10 #5-20'), findsOneWidget);
      expect(find.text('Carrera 7 #80-15'), findsOneWidget);
      expect(find.text('\$60.000'), findsOneWidget);
      expect(find.text('Vence en 0:25'), findsOneWidget);

      await pasar(tester, 5);
      expect(find.text('Vence en 0:20'), findsOneWidget);

      await pasar(tester, 21);
      expect(find.text('Calle 10 #5-20'), findsNothing);
      expect(find.text('No tienes ofertas pendientes'), findsOneWidget);
      await cerrar(tester);
    });
  });

  testWidgets('offer:rejected y offer:expired quitan sólo la oferta indicada', (tester) async {
    ofertas = [oferta('31', '9', 25), oferta('32', '10', 25, monto: 45000)];
    await conApiFalsa(backend, () async {
      await abrir(tester);
      expect(find.text('\$60.000'), findsOneWidget);
      expect(find.text('\$45.000'), findsOneWidget);

      SocketServiceClient.instance.simularEventoParaTest('offer:rejected', {'viajeId': '9', 'ofertaId': '31'});
      await avanzar(tester);
      expect(find.text('\$60.000'), findsNothing);
      expect(find.text('\$45.000'), findsOneWidget);

      SocketServiceClient.instance.simularEventoParaTest('offer:expired', {'viajeId': '10', 'ofertaId': '32'});
      await avanzar(tester);
      expect(find.text('\$45.000'), findsNothing);
      expect(find.text('No tienes ofertas pendientes'), findsOneWidget);
      await cerrar(tester);
    });
  });

  testWidgets('offer:accepted de una oferta pendiente lleva al viaje aceptado', (tester) async {
    await conApiFalsa(backend, () async {
      await abrir(tester);
      SocketServiceClient.instance.simularEventoParaTest('offer:accepted', {'viajeId': '9', 'ofertaId': '31', 'monto': 60000, 'estado': 'aceptado'});
      await avanzar(tester, 2);
      expect(find.byType(OfertaAceptadaScreen), findsOneWidget);
      final pantalla = tester.widget<OfertaAceptadaScreen>(find.byType(OfertaAceptadaScreen));
      expect(pantalla.cliente.nombre, 'Ana');
      expect(pantalla.montoOferta, '\$60.000');
      await cerrar(tester);
    });
  });

  testWidgets('error al cargar: mensaje y Reintentar', (tester) async {
    fallar = true;
    await conApiFalsa(backend, () async {
      await abrir(tester);
      expect(find.text('No se pudieron cargar tus ofertas'), findsOneWidget);
      fallar = false;
      await tester.tap(find.text('Reintentar'));
      await avanzar(tester);
      expect(find.text('No se pudieron cargar tus ofertas'), findsNothing);
      expect(find.text('\$60.000'), findsOneWidget);
      await cerrar(tester);
    });
  });

  testWidgets('se recarga al volver la app al primer plano y al deslizar hacia abajo', (tester) async {
    ofertas = [];
    final log = <http.Request>[];
    int cargas() => log.where((r) => r.url.path == '/api/drivers/offers').length;
    await conApiFalsa(backend, () async {
      await abrir(tester);
      expect(find.text('No tienes ofertas pendientes'), findsOneWidget);
      expect(cargas(), 1);

      ofertas = [oferta('31', '9', 25)];
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await avanzar(tester);
      expect(cargas(), 2);
      expect(find.text('\$60.000'), findsOneWidget);

      await tester.fling(find.text('\$60.000'), const Offset(0, 400), 1000);
      await avanzar(tester, 2);
      expect(cargas(), 3);
      await cerrar(tester);
    }, log: log);
  });
}
