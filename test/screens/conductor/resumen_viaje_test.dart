import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cargaexpress/screens/conductor/entrega_confirmada_screen.dart';
import 'package:cargaexpress/screens/conductor/resumen_viaje_screen.dart';

void main() {
  testWidgets('entrega confirmada: botón para calificar al cliente y "Volver al inicio" vuelve al inicio', (tester) async {
    var calificar = 0;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => TextButton(
          onPressed: () => Navigator.push(
            ctx,
            MaterialPageRoute(builder: (_) => EntregaConfirmadaScreen(onCalificarCliente: () => calificar++)),
          ),
          child: const Text('Inicio'),
        ),
      ),
    ));
    await tester.tap(find.text('Inicio'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Calificar al cliente'));
    expect(calificar, 1);

    await tester.tap(find.text('Volver al inicio'));
    await tester.pumpAndSettle();
    expect(find.byType(EntregaConfirmadaScreen), findsNothing);
    expect(find.text('Inicio'), findsOneWidget);
  });

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
