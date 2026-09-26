import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:cargaexpress/screens/cliente/reportar_conductor_screen.dart';
import 'package:cargaexpress/screens/cliente/viaje_detalle_screen.dart';

import '../../helpers/fake_api.dart';

void main() {
  const viaje = {
    'id': 't1',
    'estado': 'finalizado',
    'origen': {'direccion': 'Calle 1'},
    'destino': {'direccion': 'Calle 2'},
    'precioEstimado': 30000,
    'precioFinal': 32000,
    'createdAt': '2026-09-20T10:00:00.000Z',
    'conductor': {'nombre': 'Carlos'},
  };

  testWidgets('abre y muestra el detalle', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa((_) => jsonResp(viaje), () async {
      await tester.pumpWidget(const MaterialApp(home: ViajeDetalleScreen(tripId: 't1')));
      await avanzar(tester);
      expect(find.text('Calle 1'), findsOneWidget);
      expect(find.text('Finalizado'), findsOneWidget);
    });
  });

  testWidgets('un error de red no se muestra como "viaje no encontrado" y permite reintentar',
      (tester) async {
    pantallaAlta(tester);
    var falla = true;
    await conApiFalsa((_) => falla ? errorResp(500, 'Error interno') : jsonResp(viaje), () async {
      await tester.pumpWidget(const MaterialApp(home: ViajeDetalleScreen(tripId: 't1')));
      await avanzar(tester);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Viaje no encontrado'), findsNothing);
      expect(find.text('No pudimos cargar el viaje'), findsOneWidget);

      falla = false;
      await tester.tap(find.text('Reintentar'));
      await avanzar(tester);
      expect(find.text('Calle 1'), findsOneWidget);
    });
  });

  testWidgets('con conductor asignado se puede reportar y al volver queda marcado', (tester) async {
    pantallaAlta(tester);
    final log = <http.Request>[];
    await conApiFalsa(
      (req) => req.method == 'POST'
          ? jsonResp({'id': '9', 'estado': 'pendiente', 'motivo': 'otro', 'reportadoPor': 'cliente'}, 201)
          : jsonResp(viaje),
      () async {
        await tester.pumpWidget(const MaterialApp(home: ViajeDetalleScreen(tripId: 't1')));
        await avanzar(tester);
        await tester.tap(find.text('Reportar conductor'));
        await avanzar(tester);
        expect(find.byType(ReportarConductorScreen), findsOneWidget);
        expect(find.textContaining('Carlos'), findsOneWidget);

        await tester.tap(find.text('Enviar reporte'));
        await avanzar(tester);
        expect(find.byType(ReportarConductorScreen), findsNothing);
        expect(find.text('Reporte enviado. Un administrador lo revisará.'), findsOneWidget);
        expect(find.text('Ya reportaste a este conductor'), findsOneWidget);
        expect(find.text('Reportar conductor'), findsNothing);
      },
      log: log,
    );
    final post = log.singleWhere((r) => r.method == 'POST');
    expect(post.url.path, '/api/trips/t1/report');
  });

  testWidgets('sin conductor no aparece "Reportar conductor"', (tester) async {
    pantallaAlta(tester);
    final sinConductor = Map<String, dynamic>.from(viaje)
      ..remove('conductor')
      ..['estado'] = 'cancelado';
    await conApiFalsa((_) => jsonResp(sinConductor), () async {
      await tester.pumpWidget(const MaterialApp(home: ViajeDetalleScreen(tripId: 't1')));
      await avanzar(tester);
      expect(find.text('Calle 1'), findsOneWidget);
      expect(find.text('Reportar conductor'), findsNothing);
    });
  });

  testWidgets('404 sí es "viaje no encontrado"', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa((_) => errorResp(404, 'Viaje no encontrado'), () async {
      await tester.pumpWidget(const MaterialApp(home: ViajeDetalleScreen(tripId: 'x')));
      await avanzar(tester);
      expect(find.text('Viaje no encontrado'), findsOneWidget);
    });
  });
}
