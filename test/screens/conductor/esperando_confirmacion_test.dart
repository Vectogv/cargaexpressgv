import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cargaexpress/screens/conductor/esperando_confirmacion_cliente.dart';

void main() {
  testWidgets('el conductor ve que espera al cliente, no un botón para confirmar', (tester) async {
    var actualizaciones = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EsperandoConfirmacionCliente(
          minutosRevision: 15,
          onActualizar: () => actualizaciones++,
        ),
      ),
    ));

    expect(find.text('Esperando que el cliente confirme la entrega'), findsOneWidget);
    expect(find.textContaining('15 minutos'), findsOneWidget);
    expect(find.textContaining('moderador'), findsOneWidget);
    expect(find.text('Confirmar finalización'), findsNothing);

    await tester.tap(find.text('Actualizar'));
    expect(actualizaciones, 1);
  });

  testWidgets('mientras actualiza el botón queda deshabilitado', (tester) async {
    var actualizaciones = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EsperandoConfirmacionCliente(
          minutosRevision: 10,
          cargando: true,
          onActualizar: () => actualizaciones++,
        ),
      ),
    ));
    await tester.tap(find.text('Actualizar'));
    expect(actualizaciones, 0);
  });
}
