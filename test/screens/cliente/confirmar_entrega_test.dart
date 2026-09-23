import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cargaexpress/screens/cliente/confirmar_entrega_screen.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: screen));
  }

  testWidgets('el rechazo envía el motivo que escribió el cliente', (tester) async {
    String? motivo;
    await pump(
      tester,
      ConfirmarEntregaScreen(
        onConfirmar: () async {},
        onRechazar: (m) async => motivo = m,
      ),
    );

    await tester.tap(find.text('Rechazar entrega'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  Faltan dos cajas  ');
    await tester.tap(find.text('Confirmar rechazo'));
    await tester.pumpAndSettle();

    expect(motivo, 'Faltan dos cajas');
  });

  testWidgets('rechazo sin texto usa un motivo por defecto', (tester) async {
    String? motivo;
    await pump(
      tester,
      ConfirmarEntregaScreen(
        onConfirmar: () async {},
        onRechazar: (m) async => motivo = m,
      ),
    );

    await tester.tap(find.text('Rechazar entrega'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar rechazo'));
    await tester.pumpAndSettle();

    expect(motivo, 'Cliente rechazó la entrega');
  });

  testWidgets('si confirmar falla, el botón vuelve a estar disponible', (tester) async {
    var llamadas = 0;
    await pump(
      tester,
      ConfirmarEntregaScreen(
        onConfirmar: () async {
          llamadas++;
          throw Exception('sin conexión');
        },
      ),
    );

    await tester.tap(find.text('Sí, confirmar entrega'));
    await tester.pumpAndSettle();
    expect(llamadas, 1);
    expect(find.text('Sí, confirmar entrega'), findsOneWidget);

    await tester.tap(find.text('Sí, confirmar entrega'));
    await tester.pumpAndSettle();
    expect(llamadas, 2);
  });

  testWidgets('si el callback de confirmar termina sin navegar, se reactiva', (tester) async {
    var llamadas = 0;
    await pump(
      tester,
      ConfirmarEntregaScreen(onConfirmar: () async => llamadas++),
    );

    await tester.tap(find.text('Sí, confirmar entrega'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sí, confirmar entrega'));
    await tester.pumpAndSettle();
    expect(llamadas, 2);
  });
}
