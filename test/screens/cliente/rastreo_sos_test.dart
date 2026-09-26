import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import 'package:cargaexpress/screens/cliente/rastreo_screen.dart';
import 'package:cargaexpress/services/location_permission.dart';

import '../../helpers/fake_api.dart';

/// Sin GPS: el SOS se envía sin coordenadas y sin esperas.
class _SinGps extends LocationSource {
  const _SinGps();
  @override
  Future<bool> isServiceEnabled() async => false;
  @override
  Future<Position?> lastKnown() async => null;
}

Future<Map<String, dynamic>> _enviarSos(WidgetTester tester, {String? texto}) async {
  pantallaAlta(tester);
  LocationPermissionHelper.source = const _SinGps();
  addTearDown(() => LocationPermissionHelper.source = const LocationSource());
  final log = <http.Request>[];
  await conApiFalsa((req) {
    if (req.url.path == '/api/trips/active') {
      return jsonResp({
        '_id': 't1',
        'estado': 'en_curso',
        'origen': {'lat': 4.6, 'lng': -74.1, 'direccion': 'Calle 1'},
        'conductor': {'nombre': 'Carlos'},
      });
    }
    if (req.url.path == '/api/emergency') return jsonResp({});
    return jsonResp([]);
  }, () async {
    await tester.pumpWidget(const MaterialApp(home: RastreoScreen()));
    await avanzar(tester);
    await tester.tap(find.text('SOS'));
    await avanzar(tester);

    // La copia refleja a quién avisa el backend (nunca al contacto de emergencia).
    expect(find.textContaining('contacto de emergencia'), findsNothing);
    expect(find.textContaining('equipo de soporte'), findsOneWidget);

    if (texto != null) await tester.enterText(find.byType(TextField), texto);
    await tester.tap(find.text('Enviar SOS'));
    await avanzar(tester, 2);
  }, log: log);
  return jsonDecode(log.singleWhere((r) => r.url.path == '/api/emergency').body) as Map<String, dynamic>;
}

void main() {
  testWidgets('SOS envía lo que escribió el cliente como motivo', (tester) async {
    final body = await _enviarSos(tester, texto: 'Me están siguiendo');
    expect(body['motivo'], 'Me están siguiendo');
  });

  testWidgets('SOS sin texto usa el motivo por defecto (sigue siendo una acción rápida)', (tester) async {
    final body = await _enviarSos(tester);
    expect(body['motivo'], 'SOS enviado por el cliente');
  });

  testWidgets('el motivo se limita a 100 caracteres (columna motivo)', (tester) async {
    final body = await _enviarSos(tester, texto: 'x' * 150);
    expect((body['motivo'] as String).length, 100);
  });

  testWidgets('antes de que el conductor llegue, el botón SOS no hace nada', (tester) async {
    pantallaAlta(tester);
    LocationPermissionHelper.source = const _SinGps();
    addTearDown(() => LocationPermissionHelper.source = const LocationSource());
    await conApiFalsa((req) {
      if (req.url.path == '/api/trips/active') {
        return jsonResp({
          '_id': 't1',
          'estado': 'aceptado',
          'origen': {'lat': 4.6, 'lng': -74.1, 'direccion': 'Calle 1'},
          'conductor': {'nombre': 'Carlos'},
        });
      }
      return jsonResp([]);
    }, () async {
      await tester.pumpWidget(const MaterialApp(home: RastreoScreen()));
      await avanzar(tester);
      await tester.tap(find.text('SOS'));
      await avanzar(tester);
      expect(find.text('Enviar SOS'), findsNothing);
    });
  });
}
