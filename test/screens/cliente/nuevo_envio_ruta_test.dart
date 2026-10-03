import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cargaexpress/screens/cliente/nuevo_envio_screen.dart';
import 'package:cargaexpress/services/map_config.dart';

import '../../helpers/fake_api.dart';

/// Borrador con origen y destino en Popayán: al abrir, la pantalla pide la ruta.
Future<void> _abrir(WidgetTester tester, http.Client geo) async {
  SharedPreferences.setMockInitialValues({
    'nuevo_envio_origen': 'Parque Caldas',
    'nuevo_envio_origen_ll': '2.4419,-76.6063',
    'nuevo_envio_destino': 'Campanario',
    'nuevo_envio_destino_ll': '2.4593,-76.5950',
  });
  pantallaAlta(tester);
  await tester.pumpWidget(MaterialApp(home: NuevoEnvioScreen(geoClient: geo, mostrarMapa: false)));
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  tearDown(() => MapConfig.mapboxAccessToken = '');

  testWidgets('con ruta de Mapbox muestra la distancia por las calles', (tester) async {
    MapConfig.mapboxAccessToken = 'tk';
    final pedidos = <Uri>[];
    final geo = MockClient((req) async {
      pedidos.add(req.url);
      if (req.url.path.contains('/directions/')) {
        return http.Response(jsonEncode({
          'routes': [
            {
              'distance': 3200,
              'duration': 530,
              'geometry': {
                'coordinates': [
                  [-76.6063, 2.4419],
                  [-76.6000, 2.4500],
                  [-76.5950, 2.4593],
                ],
              },
            },
          ],
        }), 200);
      }
      return http.Response('error', 500);
    });
    await _abrir(tester, geo);
    expect(pedidos.any((u) => u.path.contains('/directions/v5/mapbox/driving/')), isTrue);
    expect(find.text('Por las calles: 3,2 km · unos 9 min'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('sin token no pide ruta y deja la distancia en línea recta', (tester) async {
    final pedidos = <Uri>[];
    await _abrir(tester, MockClient((req) async {
      pedidos.add(req.url);
      return http.Response('error', 500);
    }));
    expect(pedidos.where((u) => u.path.contains('/directions/')), isEmpty);
    expect(find.textContaining('en línea recta'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
