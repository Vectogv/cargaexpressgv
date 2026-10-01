import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:cargaexpress/screens/conductor/reportar_cliente_screen.dart';
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
      // Precios con punto de miles ("$30.000", no "$30000").
      expect(find.text('\$30.000'), findsOneWidget);
      expect(find.text('\$32.000'), findsOneWidget);
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

  testWidgets('el cliente no reporta (función del conductor)', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa((_) => jsonResp(viaje), () async {
      await tester.pumpWidget(const MaterialApp(home: ViajeDetalleScreen(tripId: 't1')));
      await avanzar(tester);
      expect(find.text('Carlos'), findsOneWidget);
      expect(find.textContaining('Reportar'), findsNothing);
    });
  });

  testWidgets('ya calificado: no se vuelve a ofrecer "Calificar viaje"', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa(
      (req) => req.method == 'POST' ? errorResp(400, 'Ya calificaste este viaje') : jsonResp(viaje),
      () async {
        await tester.pumpWidget(const MaterialApp(home: ViajeDetalleScreen(tripId: 't1')));
        await avanzar(tester);
        await tester.tap(find.byIcon(Icons.star_border_rounded).first);
        await tester.pump();
        await tester.tap(find.text('Enviar calificación'));
        await avanzar(tester);
        expect(find.text('Calificar viaje'), findsNothing);

        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        await tester.pumpWidget(const MaterialApp(home: ViajeDetalleScreen(tripId: 't1')));
        await avanzar(tester);
        expect(find.text('Calle 1'), findsOneWidget);
        expect(find.text('Calificar viaje'), findsNothing);
      },
    );
  });

  testWidgets('yaCalificado del servidor oculta "Calificar viaje" aunque el teléfono no lo recuerde', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa((_) => jsonResp({...viaje, 'id': 't-nuevo', 'yaCalificado': true}), () async {
      await tester.pumpWidget(const MaterialApp(home: ViajeDetalleScreen(tripId: 't-nuevo')));
      await avanzar(tester);
      expect(find.text('Calle 1'), findsOneWidget);
      expect(find.text('Calificar viaje'), findsNothing);
    });
  });

  group('como conductor', () {
    Map<String, dynamic> cerradoHace(Duration d) => {
          ...viaje,
          'cliente': {'nombre': 'Ana Cliente'},
          'completadoAt': DateTime.now().subtract(d).toUtc().toIso8601String(),
        };

    testWidgets('muestra cliente y ganancias, sin calificar, y reporta dentro de 30 min', (tester) async {
      pantallaAlta(tester);
      final log = <http.Request>[];
      await conApiFalsa(
        (req) => req.method == 'POST'
            ? jsonResp({'id': '9', 'estado': 'pendiente', 'motivo': 'no_pago', 'reportadoPor': 'conductor'}, 201)
            : jsonResp(cerradoHace(const Duration(minutes: 5))),
        () async {
          await tester.pumpWidget(const MaterialApp(home: ViajeDetalleScreen(tripId: 't1', comoConductor: true)));
          await avanzar(tester);
          expect(find.text('Ana Cliente'), findsOneWidget);
          expect(find.text('Tus ganancias'), findsOneWidget);
          expect(find.text('- \$3.200'), findsOneWidget);
          expect(find.text('\$28.800'), findsOneWidget);
          expect(find.text('Calificar viaje'), findsNothing);

          await tester.tap(find.text('Reportar cliente'));
          await avanzar(tester);
          expect(find.byType(ReportarClienteScreen), findsOneWidget);
          await tester.tap(find.text('Enviar reporte'));
          await avanzar(tester);
          expect(find.text('Ya reportaste este viaje'), findsOneWidget);
        },
        log: log,
      );
      expect(log.singleWhere((r) => r.method == 'POST').url.path, '/api/trips/t1/report');
    });

    testWidgets('pasados 30 min ya no se puede reportar', (tester) async {
      pantallaAlta(tester);
      await conApiFalsa((_) => jsonResp(cerradoHace(const Duration(minutes: 31))), () async {
        await tester.pumpWidget(const MaterialApp(home: ViajeDetalleScreen(tripId: 't1', comoConductor: true)));
        await avanzar(tester);
        expect(find.text('Reportar cliente'), findsNothing);
        expect(find.textContaining('hasta 30 minutos'), findsOneWidget);
      });
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
