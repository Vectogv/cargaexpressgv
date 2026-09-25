import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:cargaexpress/screens/cliente/ofertas_recibidas_screen.dart' show intervaloSondeoOfertas;
import 'package:cargaexpress/screens/cliente/rastreo_screen.dart';
import 'package:cargaexpress/services/socket_service_client.dart';

import '../../helpers/fake_api.dart';

/// Bug real (viaje 32 en producción, Honor 200): el conductor ofertó, al
/// cliente le llegó el push "Nueva oferta recibida" y GET /api/trips/32/offers
/// devolvía la oferta, pero la pantalla de búsqueda no la mostró. El socket
/// del cliente se corta en segundo plano y `new:offer` se pierde; la pantalla
/// sólo consultaba las ofertas al abrirse. Ahora las consulta cada
/// [intervaloSondeoOfertas], al reconectar el socket y al volver del segundo
/// plano, y la lista queda igual a la del backend (él es la regla).
class _Backend {
  String estado;
  List<Map<String, dynamic>> ofertas = [];
  int getsOfertas = 0;

  /// Si está, GET /offers espera a que se complete (simula latencia).
  Completer<List<Map<String, dynamic>>>? demoraOfertas;

  _Backend({this.estado = 'pendiente'});

  Map<String, dynamic> get viaje => {
        '_id': '32',
        'estado': estado,
        'origen': {'lat': 4.6, 'lng': -74.1, 'direccion': 'Calle 1'},
        'destino': {'lat': 4.7, 'lng': -74.0, 'direccion': 'Calle 2'},
      };

  Future<http.Response> call(http.Request req) async {
    final p = req.url.path;
    if (p == '/api/trips/active' || p == '/api/trips/32') return jsonResp(viaje);
    if (p.endsWith('/nearby-drivers')) return jsonResp({'conductores': []});
    if (p == '/api/trips/32/offers') {
      getsOfertas++;
      final demora = demoraOfertas;
      if (demora != null) return jsonResp(await demora.future);
      return jsonResp(ofertas);
    }
    return jsonResp({});
  }
}

Map<String, dynamic> _oferta(String id, {num monto = 70000}) => {
      'id': id,
      '_id': id,
      'viajeId': '32',
      'monto': monto,
      'conductor': {'id': 'c1', 'nombre': 'Pedro', 'tipoVehiculo': 'camion', 'placa': 'ABC123'},
      'expiresAt': DateTime.now().add(const Duration(seconds: 28)).toUtc().toIso8601String(),
    };

Future<void> _abrir(WidgetTester tester, _Backend backend) async {
  pantallaAlta(tester);
  await tester.pumpWidget(const MaterialApp(home: RastreoScreen()));
  await avanzar(tester);
  await tester.pump();
}

final _tarjetaOfertas = find.byKey(const Key('card_ofertas'));

void main() {
  testWidgets('viaje en pendiente: la oferta que el socket no entregó aparece por el sondeo de GET /offers',
      (tester) async {
    final backend = _Backend(estado: 'pendiente');
    await conApiFalsa(backend.call, () async {
      await _abrir(tester, backend);
      expect(_tarjetaOfertas, findsNothing);

      // El conductor oferta; el push llega pero el socket está caído.
      backend.ofertas = [_oferta('29')];
      await avanzar(tester, intervaloSondeoOfertas.inSeconds + 1);

      expect(_tarjetaOfertas, findsOneWidget);
      expect(find.text('1 oferta recibida'), findsOneWidget);
      expect(backend.getsOfertas, greaterThan(1));
    });
  });

  testWidgets('en buscando_conductor también se sondean las ofertas', (tester) async {
    final backend = _Backend(estado: 'buscando_conductor');
    await conApiFalsa(backend.call, () async {
      await _abrir(tester, backend);
      backend.ofertas = [_oferta('1'), _oferta('2', monto: 80000)];
      await avanzar(tester, intervaloSondeoOfertas.inSeconds + 1);

      expect(find.text('2 ofertas recibidas'), findsOneWidget);
    });
  });

  testWidgets('una oferta que el backend ya no devuelve (venció o fue reemplazada) deja de contarse',
      (tester) async {
    final backend = _Backend()..ofertas = [_oferta('28')];
    await conApiFalsa(backend.call, () async {
      await _abrir(tester, backend);
      expect(find.text('1 oferta recibida'), findsOneWidget);

      backend.ofertas = [];
      await avanzar(tester, intervaloSondeoOfertas.inSeconds + 1);

      expect(_tarjetaOfertas, findsNothing);
    });
  });

  testWidgets('al volver del segundo plano se consultan las ofertas de inmediato', (tester) async {
    final backend = _Backend();
    await conApiFalsa(backend.call, () async {
      await _abrir(tester, backend);
      backend.ofertas = [_oferta('29')];

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await avanzar(tester, 0.5);

      expect(find.text('1 oferta recibida'), findsOneWidget);
    });
  });

  testWidgets('al reconectarse el socket se consultan las ofertas perdidas mientras estuvo caído',
      (tester) async {
    final backend = _Backend();
    await conApiFalsa(backend.call, () async {
      await _abrir(tester, backend);
      backend.ofertas = [_oferta('29')];

      SocketServiceClient.instance.simularConexionParaTest(true);
      await avanzar(tester, 0.5);

      expect(find.text('1 oferta recibida'), findsOneWidget);
    });
  });

  testWidgets('una oferta que llega por socket mientras GET /offers está en vuelo no se pierde',
      (tester) async {
    final backend = _Backend();
    await conApiFalsa(backend.call, () async {
      await _abrir(tester, backend);
      final demora = backend.demoraOfertas = Completer();
      // Arranca un sondeo que se queda esperando la respuesta del servidor.
      await avanzar(tester, intervaloSondeoOfertas.inSeconds.toDouble());
      expect(backend.getsOfertas, greaterThan(1));

      SocketServiceClient.instance.simularEventoParaTest('new:offer', _oferta('30'));
      await avanzar(tester, 0.2);
      expect(find.text('1 oferta recibida'), findsOneWidget);

      // El servidor respondió con la foto de ANTES de la oferta 30.
      demora.complete([_oferta('29')]);
      backend.demoraOfertas = null;
      await avanzar(tester, 0.5);

      expect(find.text('2 ofertas recibidas'), findsOneWidget);
    });
  });

  testWidgets('las ofertas del socket se siguen sumando sin duplicarse con las del sondeo', (tester) async {
    final backend = _Backend();
    await conApiFalsa(backend.call, () async {
      await _abrir(tester, backend);
      SocketServiceClient.instance.simularEventoParaTest('new:offer', _oferta('29'));
      await avanzar(tester, 0.2);
      expect(find.text('1 oferta recibida'), findsOneWidget);

      backend.ofertas = [_oferta('29')];
      await avanzar(tester, intervaloSondeoOfertas.inSeconds + 1);

      expect(find.text('1 oferta recibida'), findsOneWidget);
    });
  });
}
