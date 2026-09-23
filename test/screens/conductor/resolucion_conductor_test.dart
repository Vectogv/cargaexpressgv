import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cargaexpress/contracts/disputa_resultado.dart';
import 'package:cargaexpress/screens/conductor/en_disputa_wrapper.dart';
import 'package:cargaexpress/screens/conductor/resolucion_screen.dart';

import '../../helpers/fake_api.dart';

void main() {
  test('un resultado desconocido nunca se muestra crudo', () {
    expect(etiquetaResultado('algo_nuevo'), 'Disputa resuelta');
  });

  testWidgets('a favor del conductor: banner verde y texto legible', (tester) async {
    pantallaAlta(tester);
    await tester.pumpWidget(const MaterialApp(
      home: ResolucionScreen(disputa: {
        'resultado': 'favor_conductor',
        'problema': 'Carga mojada',
        'comentarioAdmin': null,
      }),
    ));
    expect(find.text('A favor del conductor'), findsOneWidget);
    expect(find.text('favor_conductor'), findsNothing);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.text('Carga mojada'), findsOneWidget);
    expect(find.text('Comentario del administrador'), findsNothing);
    // Sin textos de demo.
    expect(find.textContaining('La evidencia confirma'), findsNothing);
  });

  testWidgets('a favor del cliente: banner en contra', (tester) async {
    pantallaAlta(tester);
    await tester.pumpWidget(const MaterialApp(
      home: ResolucionScreen(disputa: {
        'resultado': 'favor_cliente',
        'comentarioAdmin': 'Se comprobó el daño.',
      }),
    ));
    expect(find.text('A favor del cliente'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    expect(find.text('Comentario del administrador'), findsOneWidget);
    expect(find.text('Se comprobó el daño.'), findsOneWidget);
    expect(find.text('Problema reportado'), findsNothing);
  });

  testWidgets('la disputa resuelta se abre con los datos de GET /api/disputes/:id', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa((req) => jsonResp({
          'id': '7',
          'numero': 'DSP-00007',
          'estado': 'resuelta',
          'problema': 'Carga mojada',
          'resultado': 'favor_conductor',
          'reembolso': null,
          'comentarioAdmin': null,
          'fechaResolucion': '2026-09-20T15:00:00.000Z',
        }), () async {
      await tester.pumpWidget(const MaterialApp(
        home: EnDisputaWrapper(tripId: 1, disputeId: '7', inicialResuelta: true),
      ));
      await avanzar(tester, 2);
      expect(find.text('A favor del conductor'), findsOneWidget);
      expect(find.text('Carga mojada'), findsOneWidget);
    });
  });
}
