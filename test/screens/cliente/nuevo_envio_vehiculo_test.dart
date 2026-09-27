import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cargaexpress/screens/cliente/nuevo_envio_screen.dart';
import 'package:cargaexpress/screens/cliente/rastreo_screen.dart';

import '../../helpers/fake_api.dart';

/// "¿Qué vehículo necesitas?": el cliente puede pedir un tipo de vehículo
/// (informativo, no filtra a los conductores); el body lo manda al backend
/// sólo si eligió uno.
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
  testWidgets('elegir "Furgón cerrado" manda tipoVehiculoRequerido al pedir el viaje', (tester) async {
    final log = <http.Request>[];
    await conApiFalsa((req) {
      if (req.method == 'POST' && req.url.path == '/api/trips/request') {
        return jsonResp({'id': '82', 'estado': 'buscando_conductor'});
      }
      if (req.url.path == '/api/trips/active') return errorResp(404, 'Sin viaje');
      return jsonResp({'data': []});
    }, () async {
      _prefsConRuta();
      await _pump(tester);

      await tester.tap(find.byKey(const Key('opcion_vehiculo_furgon')));
      await avanzar(tester);
      await tester.enterText(find.byKey(const Key('campo_precio')), '50000');
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('btn_solicitar')));
      await tester.tap(find.byKey(const Key('btn_solicitar')));
      await avanzar(tester, 2);

      expect(find.byType(RastreoScreen), findsOneWidget);
    }, log: log);

    final peticion = log.singleWhere((r) => r.method == 'POST' && r.url.path == '/api/trips/request');
    final body = jsonDecode(peticion.body) as Map<String, dynamic>;
    expect(body['tipoVehiculoRequerido'], 'Furgón cerrado');
  });

  testWidgets('tocar la opción elegida otra vez la quita y el body no manda la clave', (tester) async {
    final log = <http.Request>[];
    await conApiFalsa((req) {
      if (req.method == 'POST' && req.url.path == '/api/trips/request') {
        return jsonResp({'id': '83', 'estado': 'buscando_conductor'});
      }
      if (req.url.path == '/api/trips/active') return errorResp(404, 'Sin viaje');
      return jsonResp({'data': []});
    }, () async {
      _prefsConRuta();
      await _pump(tester);

      await tester.tap(find.byKey(const Key('opcion_vehiculo_estacas')));
      await avanzar(tester);
      await tester.tap(find.byKey(const Key('opcion_vehiculo_estacas')));
      await avanzar(tester);
      await tester.enterText(find.byKey(const Key('campo_precio')), '50000');
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('btn_solicitar')));
      await tester.tap(find.byKey(const Key('btn_solicitar')));
      await avanzar(tester, 2);

      expect(find.byType(RastreoScreen), findsOneWidget);
    }, log: log);

    final peticion = log.singleWhere((r) => r.method == 'POST' && r.url.path == '/api/trips/request');
    final body = jsonDecode(peticion.body) as Map<String, dynamic>;
    expect(body.containsKey('tipoVehiculoRequerido'), isFalse);
  });

  testWidgets('sin elegir vehículo, el body no manda esa clave', (tester) async {
    final log = <http.Request>[];
    await conApiFalsa((req) {
      if (req.method == 'POST' && req.url.path == '/api/trips/request') {
        return jsonResp({'id': '84', 'estado': 'buscando_conductor'});
      }
      if (req.url.path == '/api/trips/active') return errorResp(404, 'Sin viaje');
      return jsonResp({'data': []});
    }, () async {
      _prefsConRuta();
      await _pump(tester);

      await tester.enterText(find.byKey(const Key('campo_precio')), '50000');
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('btn_solicitar')));
      await tester.tap(find.byKey(const Key('btn_solicitar')));
      await avanzar(tester, 2);

      expect(find.byType(RastreoScreen), findsOneWidget);
    }, log: log);

    final peticion = log.singleWhere((r) => r.method == 'POST' && r.url.path == '/api/trips/request');
    final body = jsonDecode(peticion.body) as Map<String, dynamic>;
    expect(body.containsKey('tipoVehiculoRequerido'), isFalse);
  });
}
