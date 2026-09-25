import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cargaexpress/screens/conductor/resumen_viaje_screen.dart';

void main() {
  testWidgets('"Volver al inicio" funciona aunque no le pasen callback (antes quedaba gris)', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => TextButton(
          onPressed: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => const ResumenViajeScreen())),
          child: const Text('Inicio'),
        ),
      ),
    ));
    await tester.tap(find.text('Inicio'));
    await tester.pumpAndSettle();
    expect(find.byType(ResumenViajeScreen), findsOneWidget);

    await tester.tap(find.text('Volver al inicio'));
    await tester.pumpAndSettle();
    expect(find.byType(ResumenViajeScreen), findsNothing);
    expect(find.text('Inicio'), findsOneWidget);
  });
}
