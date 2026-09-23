import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cargaexpress/screens/cliente/calificar_conductor_screen.dart';
import 'package:cargaexpress/screens/cliente/viaje_finalizado.dart';

import '../../helpers/fake_api.dart';

void main() {
  testWidgets('el cliente ve el total que pagó, sin la comisión de la plataforma', (tester) async {
    pantallaAlta(tester);
    await tester.pumpWidget(const MaterialApp(
      home: ViajeFinalizado(
        trip: {
          '_id': 't1',
          'precioFinal': 50000,
          'origen': {'direccion': 'Calle 1'},
          'destino': {'direccion': 'Calle 2'},
        },
        conductor: {'nombre': 'Carlos'},
      ),
    ));

    expect(find.textContaining('Comisi'), findsNothing);
    expect(find.text('Total pagado'), findsOneWidget);
    expect(find.text('\$50.000'), findsOneWidget);
    expect(find.text('\$45.000'), findsNothing);
  });

  testWidgets('precio como texto o ausente no rompe la pantalla', (tester) async {
    pantallaAlta(tester);
    await tester.pumpWidget(const MaterialApp(
      home: ViajeFinalizado(trip: {'precioFinal': '32000.00'}, conductor: {}),
    ));
    expect(tester.takeException(), isNull);
    expect(find.text('\$32.000'), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(
      home: ViajeFinalizado(trip: {}, conductor: {}),
    ));
    expect(tester.takeException(), isNull);
    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('ViajeFinalizado -> Calificar conductor', (tester) async {
    pantallaAlta(tester);
    await tester.pumpWidget(const MaterialApp(
      home: ViajeFinalizado(trip: {'_id': 't1', 'precioFinal': 1000}, conductor: {'nombre': 'Carlos'}),
    ));
    await tester.tap(find.text('Calificar al conductor'));
    await avanzar(tester);
    expect(find.byType(CalificarConductorScreen), findsOneWidget);
  });
}
