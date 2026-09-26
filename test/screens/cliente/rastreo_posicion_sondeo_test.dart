import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'package:cargaexpress/screens/cliente/conductor_en_la_zona_screen.dart';
import 'package:cargaexpress/screens/cliente/rastreo_screen.dart';
import 'package:cargaexpress/services/socket_service_client.dart';

import '../../helpers/fake_api.dart';

/// Bug real (Honor 200 como cliente): "Conductor en la zona" no salió solo
/// cuando el conductor llegó; el cliente tuvo que salir y volver a entrar.
/// En segundo plano el sistema corta el socket y `isConnected` sigue en true
/// un rato; la posición del conductor sólo llegaba por `driver:location`, así
/// que el mapa se congelaba y la proximidad nunca se evaluaba. Ahora el
/// seguimiento consulta GET /api/trips/:id/route (que trae la posición del
/// conductor) cada [intervaloSondeoPosicion], al volver del segundo plano y
/// al reconectar el socket.
class _Backend {
  String estado;

  /// Última posición del conductor que conoce el backend (null: aún ninguna).
  LatLng? conductor;
  String? actualizadaEn;
  int getsRuta = 0;
  int getsActivo = 0;

  _Backend({this.conductor, this.actualizadaEn}) : estado = 'conductor_en_camino';

  Map<String, dynamic> get viaje => {
        '_id': '40',
        'estado': estado,
        'origen': {'lat': 4.6, 'lng': -74.1, 'direccion': 'Calle 1'},
        'destino': {'lat': 4.7, 'lng': -74.0, 'direccion': 'Calle 2'},
        'conductor': {'_id': 'c1', 'nombre': 'Carlos', 'telefono': '3000000000'},
      };

  Future<http.Response> call(http.Request req) async {
    final p = req.url.path;
    if (p == '/api/trips/active') {
      getsActivo++;
      return jsonResp(viaje);
    }
    if (p == '/api/trips/40') return jsonResp(viaje);
    if (p == '/api/trips/40/route') {
      getsRuta++;
      final c = conductor;
      if (c == null) return errorResp(404, 'Aún no hay ubicación del conductor', 'SIN_UBICACION');
      final recogida = estado == 'aceptado' || estado == 'conductor_en_camino';
      return jsonResp({
        'tripId': '40',
        'fase': recogida ? 'recogida' : 'destino',
        'minutos': 1,
        'restanteM': 30,
        'distanciaM': 2200,
        'aproximada': false,
        'conductor': {'lat': c.latitude, 'lng': c.longitude},
        'ubicacionActualizadaEn': actualizadaEn,
        'coords': [
          [c.latitude, c.longitude],
          if (recogida) [4.6, -74.1] else [4.7, -74.0],
        ],
      });
    }
    return jsonResp({});
  }
}

/// ~2,2 km al norte del origen.
const _lejos = LatLng(4.62, -74.1);
/// ~1,7 km al norte del origen (otra posición lejana, para el socket).
const _lejos2 = LatLng(4.615, -74.1);
/// ~22 m del origen: dentro del radio de "Conductor en la zona" (50 m).
const _cerca = LatLng(4.6002, -74.1);

const _t1 = '2026-09-25T10:00:00.000Z';
const _t2 = '2026-09-25T10:00:30.000Z';

final _zona = find.byType(ConductorEnLaZonaScreen);

Future<void> _abrir(WidgetTester tester) async {
  pantallaAlta(tester);
  await tester.pumpWidget(const MaterialApp(home: RastreoScreen()));
  await avanzar(tester);
  await tester.pump();
}

void main() {
  testWidgets('sin socket: la posición llega por GET /route y abre "Conductor en la zona" dentro del radio',
      (tester) async {
    final backend = _Backend(conductor: _lejos, actualizadaEn: _t1);
    await conApiFalsa(backend.call, () async {
      await _abrir(tester);
      expect(backend.getsRuta, greaterThanOrEqualTo(1));
      expect(_zona, findsNothing);

      // El conductor llega al origen; el socket no entrega driver:location.
      backend
        ..conductor = _cerca
        ..actualizadaEn = _t2;
      await avanzar(tester, intervaloSondeoPosicion.inSeconds + 1);

      expect(_zona, findsOneWidget);
      expect(find.text('Carlos'), findsWidgets);

      // Luego el conductor marca su llegada: el aviso no se repite.
      backend.estado = 'conductor_llegada';
      await avanzar(tester, 11);
      expect(_zona, findsOneWidget);
    });
  });

  testWidgets('al volver del segundo plano se consulta la posición de inmediato', (tester) async {
    final backend = _Backend(conductor: _lejos, actualizadaEn: _t1);
    await conApiFalsa(backend.call, () async {
      await _abrir(tester);
      final antes = backend.getsRuta;
      backend
        ..conductor = _cerca
        ..actualizadaEn = _t2;

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await avanzar(tester, 0.5);

      expect(backend.getsRuta, greaterThan(antes));
      expect(_zona, findsOneWidget);
    });
  });

  testWidgets('al reconectarse el socket se consulta la posición perdida mientras estuvo caído',
      (tester) async {
    final backend = _Backend(conductor: _lejos, actualizadaEn: _t1);
    await conApiFalsa(backend.call, () async {
      await _abrir(tester);
      backend
        ..conductor = _cerca
        ..actualizadaEn = _t2;

      SocketServiceClient.instance.simularConexionParaTest(true);
      await avanzar(tester, 0.5);

      expect(_zona, findsOneWidget);
    });
  });

  testWidgets('con el socket vivo el sondeo no pisa su posición; cuando el socket calla, manda el servidor',
      (tester) async {
    final backend = _Backend(conductor: _lejos, actualizadaEn: _t1);
    await conApiFalsa(backend.call, () async {
      await _abrir(tester); // t ≈ 1 s (primer GET /route ya aplicado)
      backend
        ..conductor = _cerca
        ..actualizadaEn = _t2;
      await avanzar(tester, 6); // t ≈ 7 s
      SocketServiceClient.instance.simularEventoParaTest(
        'driver:location',
        {'lat': _lejos2.latitude, 'lng': _lejos2.longitude},
      );
      await avanzar(tester, 2); // t ≈ 9 s: sondeo de los 8 s con el socket vivo
      expect(_zona, findsNothing);

      await avanzar(tester, intervaloSondeoPosicion.inSeconds.toDouble()); // t ≈ 17 s
      expect(_zona, findsOneWidget);
    });
  });

  testWidgets('si el sondeo de estado trae conductor_llegada, el aviso de zona sale aunque no haya posición',
      (tester) async {
    final backend = _Backend(conductor: null);
    await conApiFalsa(backend.call, () async {
      await _abrir(tester);
      expect(_zona, findsNothing);

      backend.estado = 'conductor_llegada';
      await avanzar(tester, 11);

      expect(_zona, findsOneWidget);
      await avanzar(tester, 11);
      expect(_zona, findsOneWidget);
    });
  });
}
