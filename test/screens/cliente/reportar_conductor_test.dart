import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:cargaexpress/screens/cliente/reportar_conductor_screen.dart';

import '../../helpers/fake_api.dart';

void main() {
  // `Trip.toJson()` trae `_id`; los mapas del backend traen `id`.
  const tripConGuion = {
    '_id': 't1',
    'estado': 'finalizado',
    'conductor': {'nombre': 'Carlos Pérez'},
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
                MaterialPageRoute(builder: (_) => ReportarConductorScreen(trip: trip)),
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
      expect(find.byType(ReportarConductorScreen), findsNothing);
    }
  }

  testWidgets('envía POST /api/trips/:id/report con el motivo y la descripción, usando `_id`',
      (tester) async {
    pantallaAlta(tester);
    final log = <http.Request>[];
    await conApiFalsa(
      (_) => jsonResp({'id': '1', 'estado': 'pendiente', 'motivo': 'no_se_presento', 'reportadoPor': 'cliente'}, 201),
      () async {
        await abrirYEnviar(tester, tripConGuion, descripcion: 'Nunca llegó', esperarCierre: true);
      },
      log: log,
    );
    expect(log.single.method, 'POST');
    expect(log.single.url.path, '/api/trips/t1/report');
    final body = jsonDecode(log.single.body) as Map<String, dynamic>;
    expect(body['motivo'], 'no_se_presento');
    expect(body['descripcion'], 'Nunca llegó');
  });

  testWidgets('acepta el viaje con `id`, muestra el nombre del conductor y permite cambiar el motivo',
      (tester) async {
    pantallaAlta(tester);
    final log = <http.Request>[];
    await conApiFalsa(
      (_) => jsonResp({'id': '2', 'estado': 'pendiente', 'motivo': 'cobro_incorrecto'}, 201),
      () async {
        await tester.pumpWidget(const MaterialApp(home: ReportarConductorScreen(trip: tripConGuion)));
        await avanzar(tester);
        expect(find.textContaining('Carlos Pérez'), findsOneWidget);

        await tester.pumpWidget(const MaterialApp(home: ReportarConductorScreen(trip: tripSinGuion)));
        await avanzar(tester);
        expect(find.textContaining('Vas a reportar al conductor de este viaje.'), findsOneWidget);

        await tester.tap(find.byType(DropdownButton<String>));
        await avanzar(tester);
        await tester.tap(find.text('Cobro incorrecto').last);
        await avanzar(tester);
        await tester.tap(find.text('Enviar reporte'));
        await avanzar(tester);
      },
      log: log,
    );
    expect(log.single.url.path, '/api/trips/7/report');
    final body = jsonDecode(log.single.body) as Map<String, dynamic>;
    expect(body['motivo'], 'cobro_incorrecto');
    // Sin descripción no se envía el campo.
    expect(body.containsKey('descripcion'), isFalse);
  });

  testWidgets('409 (ya reportado) muestra un mensaje claro y no cierra la pantalla', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa((_) => errorResp(409, 'Ya reportaste al conductor de este viaje'), () async {
      await abrirYEnviar(tester, tripConGuion);
      expect(find.byType(ReportarConductorScreen), findsOneWidget);
      expect(find.text('Ya reportaste al conductor de este viaje.'), findsOneWidget);
    });
  });

  testWidgets('otro error del backend (422) muestra su mensaje y permite reintentar', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa((_) => jsonResp({'error': 'El viaje no tuvo conductor asignado'}, 422), () async {
      await abrirYEnviar(tester, tripConGuion);
      expect(find.byType(ReportarConductorScreen), findsOneWidget);
      expect(find.text('El viaje no tuvo conductor asignado'), findsOneWidget);
      expect(find.text('Enviar reporte'), findsOneWidget);
    });
  });

  testWidgets('el botón de enviar va en bottomNavigationBar dentro de SafeArea', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa((_) => jsonResp({}), () async {
      await tester.pumpWidget(const MaterialApp(home: ReportarConductorScreen(trip: tripConGuion)));
      await avanzar(tester);
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.bottomNavigationBar, isA<SafeArea>());
      expect(
        find.descendant(of: find.byWidget(scaffold.bottomNavigationBar!), matching: find.text('Enviar reporte')),
        findsOneWidget,
      );
    });
  });
}
