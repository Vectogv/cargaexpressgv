import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cargaexpress/screens/cliente/rastreo_screen.dart';
import 'package:cargaexpress/screens/cliente/rastreo_ui.dart';

import '../../helpers/fake_api.dart';

/// Vista "Buscando conductor" (`BusquedaConductorView`) tal como la arma
/// `RastreoScreen._buildNearbyMap`: los vehículos que llega por
/// `/api/trips/:id/nearby-drivers` se dibujan como camiones (`MarcadorCamion`)
/// en el mapa real y alimentan el contador de "vehículos cerca". Las ofertas
/// que ya existían (`GET /offers`) alimentan el contador de "Ver ofertas".
Map<String, dynamic> _viaje() => {
      '_id': 't1',
      'estado': 'buscando_conductor',
      'origen': {'lat': 4.6, 'lng': -74.1, 'direccion': 'Calle 1'},
      'destino': {'lat': 4.7, 'lng': -74.0, 'direccion': 'Calle 2'},
    };

Future<void> _abrir(
  WidgetTester tester, {
  required List<Map<String, dynamic>> cercanos,
  List<Map<String, dynamic>> ofertas = const [],
}) async {
  pantallaAlta(tester);
  await conApiFalsa((req) {
    final p = req.url.path;
    if (p == '/api/trips/active') return jsonResp(_viaje());
    if (p.endsWith('/nearby-drivers')) return jsonResp({'conductores': cercanos});
    if (p == '/api/trips/t1/offers') return jsonResp(ofertas);
    return jsonResp({});
  }, () async {
    await tester.pumpWidget(const MaterialApp(home: RastreoScreen()));
    await avanzar(tester);
    // flutter_map dibuja los marcadores un frame después del primer layout.
    await tester.pump();
  });
}

void main() {
  testWidgets('los vehículos cercanos del backend se dibujan como camiones en el mapa', (tester) async {
    await _abrir(tester, cercanos: [
      {'lat': 4.601, 'lng': -74.101, 'tipoVehiculo': 'camion'},
      {'lat': 4.602, 'lng': -74.102, 'tipoVehiculo': 'camioneta'},
    ]);

    expect(find.byType(MarcadorCamion), findsNWidgets(2));
    expect(find.text('2 vehículos disponibles a menos de 2 km'), findsOneWidget);
    expect(find.text('Aún no hay vehículos cerca, seguimos buscando'), findsNothing);
  });

  testWidgets('sin vehículos cercanos no se dibuja ningún camión y se ve el aviso honesto', (tester) async {
    await _abrir(tester, cercanos: []);

    expect(find.byType(MarcadorCamion), findsNothing);
    expect(find.text('Aún no hay vehículos cerca, seguimos buscando'), findsOneWidget);
  });

  testWidgets('un vehículo sin lat/lng numéricos no se dibuja (no revienta el mapa)', (tester) async {
    await _abrir(tester, cercanos: [
      {'lat': 4.601, 'lng': -74.101, 'tipoVehiculo': 'camion'},
      {'lat': null, 'lng': null, 'tipoVehiculo': 'camion'},
    ]);

    expect(find.byType(MarcadorCamion), findsNWidgets(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('las ofertas ya existentes (GET) alimentan el contador "Ver ofertas"', (tester) async {
    await _abrir(tester, cercanos: [], ofertas: [
      {'_id': 'o1', 'monto': 20000},
      {'_id': 'o2', 'monto': 22000},
    ]);

    expect(find.text('2 ofertas recibidas'), findsOneWidget);
    expect(find.text('Ver ofertas'), findsOneWidget);
    expect(find.byKey(const Key('card_ofertas')), findsOneWidget);
  });

  testWidgets('sin ofertas no se muestra la tarjeta de ofertas', (tester) async {
    await _abrir(tester, cercanos: [], ofertas: []);

    expect(find.byKey(const Key('card_ofertas')), findsNothing);
    expect(find.textContaining('ofertas recibidas'), findsNothing);
  });
}
