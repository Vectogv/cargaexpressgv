import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import 'package:cargaexpress/services/location_permission.dart';
import 'package:cargaexpress/services/sos_service.dart';

import '../helpers/fake_api.dart';

class _FakeSource extends LocationSource {
  _FakeSource({this.servicio = true, this.actual, this.ultima});

  final bool servicio;
  final Position? actual;
  final Position? ultima;
  int ajustesAbiertos = 0;

  @override
  Future<bool> isServiceEnabled() async => servicio;
  @override
  Future<LocationPermission> checkPermission() async => LocationPermission.whileInUse;
  @override
  Future<LocationPermission> requestPermission() async => LocationPermission.whileInUse;
  @override
  Future<Position> current(LocationAccuracy accuracy, Duration timeLimit) async {
    if (actual != null) return actual!;
    throw Exception('sin señal');
  }

  @override
  Future<Position?> lastKnown() async => ultima;
  @override
  Future<bool> openLocationSettings() async {
    ajustesAbiertos++;
    return true;
  }

  @override
  Future<bool> openAppSettings() async {
    ajustesAbiertos++;
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => LocationPermissionHelper.source = const LocationSource());

  Future<Map<String, dynamic>> enviar() async {
    final log = <http.Request>[];
    await conApiFalsa((_) => jsonResp({'id': 9}), () async {
      final alerta = await SosService.sendAlert(tripId: 't1', motivo: 'SOS');
      expect(alerta.id, isNotNull);
    }, log: log);
    return jsonDecode(log.single.body) as Map<String, dynamic>;
  }

  test('con GPS envía la posición actual', () async {
    LocationPermissionHelper.source = _FakeSource(actual: _pos(4.6, -74.1));
    final body = await enviar();
    expect(body['lat'], 4.6);
    expect(body['lng'], -74.1);
  });

  test('con el GPS apagado usa la última posición conocida y no abre ajustes', () async {
    final fuente = _FakeSource(servicio: false, ultima: _pos(4.7, -74.0));
    LocationPermissionHelper.source = fuente;
    final body = await enviar();
    expect(body['lat'], 4.7);
    expect(body['lng'], -74.0);
    expect(fuente.ajustesAbiertos, 0);
  });

  test('sin ninguna posición envía el SOS sin coordenadas (nunca 0,0)', () async {
    LocationPermissionHelper.source = _FakeSource(servicio: false);
    final body = await enviar();
    expect(body.containsKey('lat'), isFalse);
    expect(body.containsKey('lng'), isFalse);
    expect(body['viajeId'], 't1');
  });
}
