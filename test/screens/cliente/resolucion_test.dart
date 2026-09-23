import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cargaexpress/screens/cliente/disputa_en_revision_screen.dart';
import 'package:cargaexpress/screens/cliente/resolucion_screen.dart';

import '../../helpers/fake_api.dart';

void main() {
  const disputa = {
    'id': '7',
    'numero': 'DSP-00007',
    'estado': 'resuelta',
    'problema': 'Carga mojada',
    'resultado': 'favor_cliente',
    'reembolso': 15000,
    'comentarioAdmin': 'Se comprobó el daño.',
    'fechaResolucion': '2026-09-20T15:00:00.000Z',
  };

  test('textos de resolución a partir del backend', () {
    expect(etiquetaResultado('favor_cliente'), 'A favor del cliente');
    expect(etiquetaResultado('favor_conductor'), 'A favor del conductor');
    expect(etiquetaResultado(null), 'Sin resultado');
    expect(formatoReembolso(15000), '\$15.000');
    expect(formatoReembolso('20000.00'), '\$20.000');
    expect(formatoReembolso(null), isNull);
    expect(formatoReembolso(0), isNull);
  });

  testWidgets('la resolución y su detalle muestran los datos reales, no los de demo', (tester) async {
    pantallaAlta(tester);
    await tester.pumpWidget(const MaterialApp(home: ResolucionScreen(disputa: disputa)));
    expect(find.text('A favor del cliente'), findsOneWidget);
    expect(find.text('\$15.000'), findsOneWidget);

    await tester.tap(find.text('Ver detalle'));
    await tester.pumpAndSettle();

    expect(find.text('DSP-00007'), findsOneWidget);
    expect(find.text('Carga mojada'), findsOneWidget);
    expect(find.text('Se comprobó el daño.'), findsOneWidget);
    expect(find.text('20/09/2026'), findsOneWidget);
    expect(find.text('DIS-2024-0610-0012'), findsNothing);
    expect(find.text('La carga llegó dañada'), findsNothing);
  });

  testWidgets('sin reembolso ni comentario no inventa valores', (tester) async {
    pantallaAlta(tester);
    await tester.pumpWidget(const MaterialApp(
      home: ResolucionScreen(disputa: {'estado': 'resuelta', 'resultado': 'favor_conductor'}),
    ));
    expect(find.text('A favor del conductor'), findsOneWidget);
    expect(find.text('\$20.000'), findsNothing);

    await tester.tap(find.text('Ver detalle'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Después de revisar'), findsNothing);
  });

  testWidgets('disputa resuelta con reembolso numérico abre la resolución sin fallar', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa((_) => jsonResp(disputa), () async {
      await tester.pumpWidget(const MaterialApp(home: DisputaEnRevisionScreen(disputeId: '7')));
      await avanzar(tester);
      await tester.tap(find.text('Ver resolución'));
      await avanzar(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('\$15.000'), findsOneWidget);
    });
  });
}
