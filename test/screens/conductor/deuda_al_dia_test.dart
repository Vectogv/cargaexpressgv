import 'package:cargaexpress/screens/conductor/aviso_cuenta_pago.dart';
import 'package:cargaexpress/screens/shared/ui_compartida.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget aviso(Map<String, dynamic> deuda) => MaterialApp(
        home: Scaffold(body: AvisoCuentaPago(deuda: deuda, onAbrirPagos: () {})),
      );

  testWidgets('la deuda se desvanece y queda "Al día" cuando se aprueba el pago', (tester) async {
    await tester.pumpWidget(aviso({'estadoCuenta': 'esperando_confirmacion', 'montoDeuda': 50000}));
    expect(find.byKey(const Key('aviso_cuenta_pago')), findsOneWidget);
    expect(find.text('Al día'), findsNothing);

    await tester.pumpWidget(aviso({'estadoCuenta': 'activa', 'montoDeuda': 0}));
    await tester.pump(const Duration(milliseconds: 300));
    // Mientras sale, el aviso anterior sigue visible (desvaneciéndose).
    expect(find.byKey(const Key('aviso_cuenta_pago')), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byKey(const Key('aviso_cuenta_pago')), findsNothing);
    expect(find.text('Al día'), findsOneWidget);
    expect(find.text('Gerencia aprobó tu pago. Ya puedes conectarte.'), findsOneWidget);
  });

  testWidgets('sin deuda desde el principio no muestra nada', (tester) async {
    await tester.pumpWidget(aviso({'estadoCuenta': 'activa', 'montoDeuda': 0}));
    expect(find.text('Al día'), findsNothing);
    expect(find.byKey(const Key('aviso_cuenta_pago')), findsNothing);
  });

  testWidgets('CampoPin acepta 4 dígitos y avisa', (tester) async {
    String? valor;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: CampoPin(onChanged: (v) => valor = v))));
    await tester.enterText(find.byType(TextField), '12a345');
    await tester.pump();
    expect(valor, '1234');
  });

  testWidgets('DialogoApp muestra el título y los botones', (tester) async {
    var principal = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DialogoApp(
          icono: Icons.info_outline,
          titulo: 'Cancelar viaje',
          cuerpo: '¿Seguro?',
          textoPrincipal: 'Sí, cancelar',
          onPrincipal: () => principal++,
          textoSecundario: 'Volver',
          onSecundario: () {},
        ),
      ),
    ));
    expect(find.text('Cancelar viaje'), findsOneWidget);
    expect(find.text('Volver'), findsOneWidget);
    await tester.tap(find.text('Sí, cancelar'));
    expect(principal, 1);
  });
}
