import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cargaexpress/screens/cliente/nuevo_envio_screen.dart';
import 'package:cargaexpress/screens/cliente/rastreo_screen.dart';

import '../../helpers/fake_api.dart';

/// Deja el origen y el destino ya elegidos (mismo mecanismo que el borrador
/// guardado por la pantalla) para no depender del GPS en estas pruebas.
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
  group('Mis rutas (GET/DELETE /api/favorites)', () {
    testWidgets('borrar una ruta la quita de la lista y elegir otra llena el formulario', (tester) async {
      final favoritos = [
        {
          'id': 1,
          'nombre': 'Casa-Trabajo',
          'origen': {'direccion': 'Casa', 'lat': 6.21, 'lng': -75.57},
          'destino': {'direccion': 'Trabajo', 'lat': 6.31, 'lng': -75.67},
        },
        {
          'id': 2,
          'nombre': 'Bodega-Cliente',
          'origen': {'direccion': 'Bodega', 'lat': 6.22, 'lng': -75.58},
          'destino': {'direccion': 'Cliente', 'lat': 6.32, 'lng': -75.68},
        },
      ];
      final log = <http.Request>[];
      await conApiFalsa((req) {
        if (req.method == 'GET' && req.url.path == '/api/favorites') return jsonResp(favoritos);
        if (req.method == 'DELETE' && req.url.path == '/api/favorites/1') {
          favoritos.removeWhere((f) => f['id'] == 1);
          return jsonResp({'success': true});
        }
        return jsonResp({'data': []});
      }, () async {
        _prefsConRuta();
        await _pump(tester);

        await tester.tap(find.byKey(const Key('btn_mis_rutas')));
        await avanzar(tester);
        expect(find.text('Casa-Trabajo'), findsOneWidget);
        expect(find.text('Bodega-Cliente'), findsOneWidget);

        // Borrar "Casa-Trabajo".
        await tester.tap(find.byIcon(Icons.delete_outline).first);
        await avanzar(tester);
        expect(find.text('Casa-Trabajo'), findsNothing);
        expect(find.text('Bodega-Cliente'), findsOneWidget);

        // Elegir la que queda: llena origen y destino como una dirección buscada.
        await tester.tap(find.text('Bodega-Cliente'));
        await avanzar(tester);
        expect(find.text('Bodega'), findsOneWidget);
        expect(find.text('Cliente'), findsOneWidget);
      }, log: log);

      expect(log.any((r) => r.method == 'DELETE' && r.url.path == '/api/favorites/1'), isTrue);
    });
  });

  group('Guardar ruta (POST /api/favorites)', () {
    testWidgets('con origen y destino elegidos, guarda la ruta con nombre', (tester) async {
      final log = <http.Request>[];
      await conApiFalsa((req) {
        if (req.method == 'POST' && req.url.path == '/api/favorites') return jsonResp({'id': 9});
        return jsonResp({'data': []});
      }, () async {
        _prefsConRuta();
        await _pump(tester);

        expect(find.byKey(const Key('btn_guardar_ruta')), findsOneWidget);
        await tester.tap(find.byKey(const Key('btn_guardar_ruta')));
        await avanzar(tester);
        await tester.enterText(find.byType(TextField).last, 'Mi ruta frecuente');
        await tester.tap(find.text('Guardar'));
        await avanzar(tester);

        expect(find.text('Ruta guardada.'), findsOneWidget);
      }, log: log);

      final peticion = log.singleWhere((r) => r.method == 'POST' && r.url.path == '/api/favorites');
      final body = jsonDecode(peticion.body) as Map<String, dynamic>;
      expect(body['nombre'], 'Mi ruta frecuente');
      expect(body['origenDireccion'], 'Origen actual');
      expect(body['origenLat'], 6.20);
      expect(body['destinoDireccion'], 'Destino actual');
      expect(body['destinoLng'], -75.60);
    });
  });

  group('Programar (POST /api/trips/reserve)', () {
    testWidgets('elegir "Programar" y fecha/hora reserva el viaje con esos datos', (tester) async {
      final log = <http.Request>[];
      await conApiFalsa((req) {
        if (req.method == 'POST' && req.url.path == '/api/trips/reserve') {
          return jsonResp({'id': '77', 'estado': 'reservado'});
        }
        if (req.url.path == '/api/trips/active') return errorResp(404, 'Sin viaje');
        return jsonResp({'data': []});
      }, () async {
        _prefsConRuta();
        await _pump(tester);

        await tester.tap(find.text('Programar'));
        await avanzar(tester);
        // Aceptar la fecha y la hora propuestas por defecto en los pickers nativos.
        await tester.tap(find.text('OK'));
        await avanzar(tester);
        await tester.tap(find.text('OK'));
        await avanzar(tester);

        expect(find.byKey(const Key('btn_solicitar')), findsOneWidget);
        expect(find.text('Reservar viaje'), findsOneWidget);

        await tester.enterText(find.byKey(const Key('campo_precio')), '150000');
        await tester.pump();
        await tester.tap(find.byKey(const Key('btn_solicitar')));
        await avanzar(tester, 2);

        expect(find.byType(RastreoScreen), findsOneWidget);
      }, log: log);

      final peticion = log.singleWhere((r) => r.method == 'POST' && r.url.path == '/api/trips/reserve');
      final body = jsonDecode(peticion.body) as Map<String, dynamic>;
      expect(body['precioCliente'], 150000);
      expect(body['fechaProgramada'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
      expect(body['horaProgramada'], matches(RegExp(r'^([01]\d|2[0-3]):[0-5]\d$')));
    });
  });
}
