import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cargaexpress/screens/cliente/nuevo_envio_screen.dart';
import 'package:cargaexpress/screens/cliente/rastreo_screen.dart';

import '../../helpers/fake_api.dart';

/// "Quién recibe la carga": el cliente puede indicar nombre y teléfono de
/// quien recibe (opcionales), el body los manda al backend
/// (POST /api/trips/request / /api/trips/reserve) sólo si no están vacíos.
void _prefsConRuta() {
  SharedPreferences.setMockInitialValues({
    'nuevo_envio_origen': 'Origen actual',
    'nuevo_envio_origen_ll': '6.20,-75.50',
    'nuevo_envio_destino': 'Destino actual',
    'nuevo_envio_destino_ll': '6.30,-75.60',
  });
}

Future<void> _pump(WidgetTester tester) async {
  pantallaAlta(tester);
  await tester.pumpWidget(const MaterialApp(home: NuevoEnvioScreen(mostrarMapa: false)));
  await avanzar(tester);
}

void main() {
  testWidgets('con nombre y teléfono de quien recibe, el body los manda al pedir el viaje', (tester) async {
    final log = <http.Request>[];
    await conApiFalsa((req) {
      if (req.method == 'POST' && req.url.path == '/api/trips/request') {
        return jsonResp({'id': '80', 'estado': 'buscando_conductor'});
      }
      if (req.url.path == '/api/trips/active') return errorResp(404, 'Sin viaje');
      return jsonResp({'data': []});
    }, () async {
      _prefsConRuta();
      await _pump(tester);

      await tester.enterText(find.byKey(const Key('campo_receptor_nombre')), 'Juan Pérez');
      await tester.enterText(find.byKey(const Key('campo_receptor_telefono')), '3009998888');
      await tester.enterText(find.byKey(const Key('campo_precio')), '50000');
      await tester.pump();
      await tester.tap(find.byKey(const Key('btn_solicitar')));
      await avanzar(tester, 2);

      expect(find.byType(RastreoScreen), findsOneWidget);
    }, log: log);

    final peticion = log.singleWhere((r) => r.method == 'POST' && r.url.path == '/api/trips/request');
    final body = jsonDecode(peticion.body) as Map<String, dynamic>;
    expect(body['receptorNombre'], 'Juan Pérez');
    expect(body['receptorTelefono'], '3009998888');
  });

  testWidgets('sin nombre ni teléfono de quien recibe, el body no manda esas claves', (tester) async {
    final log = <http.Request>[];
    await conApiFalsa((req) {
      if (req.method == 'POST' && req.url.path == '/api/trips/request') {
        return jsonResp({'id': '81', 'estado': 'buscando_conductor'});
      }
      if (req.url.path == '/api/trips/active') return errorResp(404, 'Sin viaje');
      return jsonResp({'data': []});
    }, () async {
      _prefsConRuta();
      await _pump(tester);

      await tester.enterText(find.byKey(const Key('campo_precio')), '50000');
      await tester.pump();
      await tester.tap(find.byKey(const Key('btn_solicitar')));
      await avanzar(tester, 2);

      expect(find.byType(RastreoScreen), findsOneWidget);
    }, log: log);

    final peticion = log.singleWhere((r) => r.method == 'POST' && r.url.path == '/api/trips/request');
    final body = jsonDecode(peticion.body) as Map<String, dynamic>;
    expect(body.containsKey('receptorNombre'), isFalse);
    expect(body.containsKey('receptorTelefono'), isFalse);
  });
}
