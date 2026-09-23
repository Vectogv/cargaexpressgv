import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cargaexpress/screens/cliente/nuevo_envio_screen.dart';
import 'package:cargaexpress/services/location_permission.dart';

class _FakeSource extends LocationSource {
  _FakeSource({
    this.permission = LocationPermission.whileInUse,
    this.onCurrent,
    this.last,
  });

  final LocationPermission permission;
  final Future<Position> Function()? onCurrent;
  final Position? last;
  int abrirAjustesApp = 0;

  @override
  Future<bool> isServiceEnabled() async => true;
  @override
  Future<LocationPermission> checkPermission() async => permission;
  @override
  Future<LocationPermission> requestPermission() async => permission;
  @override
  Future<Position> current(LocationAccuracy accuracy, Duration timeLimit) =>
      onCurrent?.call() ?? Completer<Position>().future; // sin señal: nunca responde
  @override
  Future<Position?> lastKnown() async => last;
  @override
  Future<bool> openLocationSettings() async => true;
  @override
  Future<bool> openAppSettings() async {
    abrirAjustesApp++;
    return true;
  }
}

Position _pos(double lat, double lng) => Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime(2026),
      accuracy: 20,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

/// Nominatim simulado: reverse falla (sin dirección), search devuelve un resultado.
http.Client _geoClient() => MockClient((req) async {
      if (req.url.path.contains('search')) {
        return http.Response(
          jsonEncode([
            {'place_id': 1, 'display_name': 'Calle 10, Medellín', 'lat': '6.21', 'lon': '-75.57'},
          ]),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response('error', 500);
    });

Future<void> _pumpScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: NuevoEnvioScreen(geoClient: _geoClient(), mostrarMapa: false),
  ));
  await tester.pump();
  await tester.pump();
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 3));
}

ElevatedButton _boton(WidgetTester tester) =>
    tester.widget<ElevatedButton>(find.byKey(const Key('btn_solicitar')));

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() {
    LocationPermissionHelper.source = const LocationSource();
  });

  group('cobertura del origen (GET /api/config/coverage)', () {
    // Zona rectangular alrededor de Medellín.
    http.Response cobertura(http.Request req) => http.Response(
          jsonEncode({
            'zonas': [
              {'clave': 'med', 'nombre': 'Medellín', 'norte': 6.4, 'sur': 6.1, 'este': -75.4, 'oeste': -75.7},
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );

    Future<void> conOrigen(WidgetTester tester, double lat, double lng) async {
      LocationPermissionHelper.source = _FakeSource(onCurrent: () async => _pos(lat, lng));
      await http.runWithClient(() async {
        await _pumpScreen(tester);
        await tester.pump(const Duration(seconds: 2));
        await tester.pump();
      }, () => MockClient((req) async => cobertura(req)));
    }

    testWidgets('origen fuera de cobertura se avisa al elegirlo', (tester) async {
      await conOrigen(tester, 4.6, -74.1); // Bogotá
      expect(find.byKey(const Key('aviso_fuera_cobertura')), findsOneWidget);
      await _dispose(tester);
    });

    testWidgets('origen dentro de cobertura no muestra aviso', (tester) async {
      await conOrigen(tester, 6.25, -75.56);
      expect(find.byKey(const Key('aviso_fuera_cobertura')), findsNothing);
      await _dispose(tester);
    });

    // El backend también rechaza (422) un destino fuera de cobertura.
    Future<void> conDestino(WidgetTester tester, String ll) async {
      SharedPreferences.setMockInitialValues({
        'nuevo_envio_destino': 'Destino guardado',
        'nuevo_envio_destino_ll': ll,
      });
      await conOrigen(tester, 6.25, -75.56);
    }

    testWidgets('destino fuera de cobertura se avisa', (tester) async {
      await conDestino(tester, '4.6,-74.1'); // Bogotá
      expect(find.byKey(const Key('aviso_fuera_cobertura')), findsNothing);
      expect(find.byKey(const Key('aviso_destino_fuera_cobertura')), findsOneWidget);
      expect(find.textContaining('destino está fuera de nuestra zona de cobertura'), findsOneWidget);
      await _dispose(tester);
    });

    testWidgets('destino dentro de cobertura no muestra aviso', (tester) async {
      await conDestino(tester, '6.3,-75.6');
      expect(find.byKey(const Key('aviso_destino_fuera_cobertura')), findsNothing);
      await _dispose(tester);
    });
  });

  testWidgets('sin señal GPS la carga de ubicación termina y ofrece alternativas',
      (tester) async {
    LocationPermissionHelper.source = _FakeSource();
    await _pumpScreen(tester);

    expect(find.text('Obteniendo tu ubicación…'), findsOneWidget);
    expect(find.text('¿Dónde recogemos?'), findsOneWidget);
    expect(find.text('¿A dónde lo llevamos?'), findsOneWidget);
    expect(_boton(tester).onPressed, isNull);
    expect(find.text('Para continuar indica: origen, destino y precio.'), findsOneWidget);

    // Alta precisión (10 s) + última conocida (sin datos) + media (6 s).
    await tester.pump(const Duration(seconds: 12));
    await tester.pump(const Duration(seconds: 12));
    await tester.pump();

    expect(find.text('Obteniendo tu ubicación…'), findsNothing);
    expect(find.textContaining('No pudimos obtener tu ubicación'), findsOneWidget);
    expect(find.byKey(const Key('btn_reintentar_ubicacion')), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Buscar dirección'), findsOneWidget);

    await _dispose(tester);
  });

  testWidgets('permiso bloqueado muestra el botón para abrir ajustes', (tester) async {
    final fake = _FakeSource(permission: LocationPermission.deniedForever);
    LocationPermissionHelper.source = fake;
    await _pumpScreen(tester);
    await tester.pump();

    expect(find.text('Obteniendo tu ubicación…'), findsNothing);
    expect(find.textContaining('permiso de ubicación está bloqueado'), findsOneWidget);
    await tester.tap(find.text('Abrir ajustes'));
    await tester.pump();
    expect(fake.abrirAjustesApp, 1);

    await _dispose(tester);
  });

  testWidgets(
      'origen por última posición conocida, destino buscado a mano y '
      'solicitar se habilita solo con todo válido', (tester) async {
    LocationPermissionHelper.source = _FakeSource(
      onCurrent: () => Future<Position>.error(TimeoutException('sin fix')),
      last: _pos(6.2, -75.5),
    );
    await _pumpScreen(tester);
    await tester.pump(const Duration(seconds: 2));

    // La geocodificación inversa falló: se muestran las coordenadas.
    expect(find.text('Mi ubicación actual (6.20000, -75.50000)'), findsOneWidget);
    expect(find.text('Obteniendo tu ubicación…'), findsNothing);
    expect(_boton(tester).onPressed, isNull);

    // Destino: fila -> "Buscar dirección" -> escribir -> elegir resultado.
    await tester.tap(find.byKey(const Key('fila_destino')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('Buscar dirección'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.enterText(find.byType(TextField).last, 'Calle 10');
    await tester.tap(find.text('Buscar'));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('Calle 10, Medellín'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Calle 10, Medellín'), findsOneWidget);
    expect(find.textContaining('Distancia aprox.'), findsOneWidget);
    expect(_boton(tester).onPressed, isNull); // falta el precio
    expect(find.text('Para continuar indica: precio.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('campo_precio')), '150000');
    await tester.pump();
    expect(find.text('150.000'), findsOneWidget);
    expect(_boton(tester).onPressed, isNotNull);

    await tester.enterText(find.byKey(const Key('campo_precio')), '');
    await tester.pump();
    expect(_boton(tester).onPressed, isNull);
    expect(find.textContaining('Ingresa el valor que ofreces'), findsOneWidget);

    await _dispose(tester);
  });

  test('formatearMiles usa separador de miles', () {
    expect(formatearMiles('150000'), '150.000');
    expect(formatearMiles('1.234.567'), '1.234.567');
    expect(formatearMiles('0050'), '50');
    expect(formatearMiles(''), '');
  });
}
