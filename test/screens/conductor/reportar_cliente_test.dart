import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:cargaexpress/screens/conductor/reportar_cliente_screen.dart';
import 'package:cargaexpress/screens/shared/ui_compartida.dart';

import '../../helpers/fake_api.dart';

void main() {
  // `Trip.toJson()` trae `_id`; los mapas del backend traen `id`.
  const tripConGuion = {
    '_id': 't1',
    'estado': 'finalizado',
    'cliente': {'nombre': 'Carlos Pérez'},
  };
  const tripSinGuion = {'id': '7', 'estado': 'finalizado'};

  Future<void> abrirYEnviar(
    WidgetTester tester,
    Map<String, dynamic> trip, {
    String? descripcion,
    bool esperarCierre = false,
  }) async {
    bool? resultado;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              resultado = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => ReportarClienteScreen(trip: trip)),
              );
            },
            child: const Text('abrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await avanzar(tester);
    if (descripcion != null) {
      await tester.enterText(find.byType(TextField), descripcion);
    }
    await tester.tap(find.text('Enviar reporte'));
    await avanzar(tester);
    if (esperarCierre) {
      expect(resultado, isTrue);
      expect(find.byType(ReportarClienteScreen), findsNothing);
    }
  }

  testWidgets('envía POST /api/trips/:id/report con el motivo y la descripción, usando `_id`',
      (tester) async {
    pantallaAlta(tester);
    final log = <http.Request>[];
    await conApiFalsa(
      (_) => jsonResp({'id': '1', 'estado': 'pendiente', 'motivo': 'no_pago', 'reportadoPor': 'conductor'}, 201),
      () async {
        await abrirYEnviar(tester, tripConGuion, descripcion: 'No pagó', esperarCierre: true);
      },
      log: log,
    );
    expect(log.single.method, 'POST');
    expect(log.single.url.path, '/api/trips/t1/report');
    final body = jsonDecode(log.single.body) as Map<String, dynamic>;
    expect(body['motivo'], 'no_pago');
    expect(body['descripcion'], 'No pagó');
  });

  testWidgets('acepta el viaje con `id`, muestra el nombre del cliente y permite cambiar el motivo',
      (tester) async {
    pantallaAlta(tester);
    final log = <http.Request>[];
    await conApiFalsa(
      (_) => jsonResp({'id': '2', 'estado': 'pendiente', 'motivo': 'comportamiento'}, 201),
      () async {
        await tester.pumpWidget(const MaterialApp(home: ReportarClienteScreen(trip: tripConGuion)));
        await avanzar(tester);
        expect(find.textContaining('Carlos Pérez'), findsOneWidget);

        await tester.pumpWidget(const MaterialApp(home: ReportarClienteScreen(trip: tripSinGuion)));
        await avanzar(tester);
        expect(find.textContaining('Vas a reportar al cliente de este viaje.'), findsOneWidget);

        await tester.tap(find.byType(DropdownButton<String>));
        await avanzar(tester);
        await tester.tap(find.text('Comportamiento inadecuado').last);
        await avanzar(tester);
        await tester.tap(find.text('Enviar reporte'));
        await avanzar(tester);
      },
      log: log,
    );
    expect(log.single.url.path, '/api/trips/7/report');
    final body = jsonDecode(log.single.body) as Map<String, dynamic>;
    expect(body['motivo'], 'comportamiento');
    // Sin descripción no se envía el campo.
    expect(body.containsKey('descripcion'), isFalse);
  });

  testWidgets('400 (ya reportado) muestra un mensaje claro y no cierra la pantalla', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa((_) => errorResp(400, 'Ya has reportado este viaje'), () async {
      await abrirYEnviar(tester, tripConGuion);
      expect(find.byType(ReportarClienteScreen), findsOneWidget);
      expect(find.text('Ya reportaste al cliente de este viaje.'), findsOneWidget);
    });
  });

  testWidgets('otro error del backend (422) muestra su mensaje y permite reintentar', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa((_) => jsonResp({'error': 'El viaje no tuvo conductor asignado'}, 422), () async {
      await abrirYEnviar(tester, tripConGuion);
      expect(find.byType(ReportarClienteScreen), findsOneWidget);
      expect(find.text('El viaje no tuvo conductor asignado'), findsOneWidget);
      expect(find.text('Enviar reporte'), findsOneWidget);
    });
  });

  testWidgets('el botón de enviar va en bottomNavigationBar en una BarraInferiorFija (sube con el teclado)', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa((_) => jsonResp({}), () async {
      await tester.pumpWidget(const MaterialApp(home: ReportarClienteScreen(trip: tripConGuion)));
      await avanzar(tester);
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.bottomNavigationBar, isA<BarraInferiorFija>());
      expect(
        find.descendant(of: find.byWidget(scaffold.bottomNavigationBar!), matching: find.text('Enviar reporte')),
        findsOneWidget,
      );
    });
  });
}
