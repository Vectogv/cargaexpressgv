import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cargaexpress/screens/cliente/oferta_aceptada_screen.dart';
import 'package:cargaexpress/screens/cliente/rastreo_screen.dart';

void main() {
  testWidgets('"Ver seguimiento" usa el contexto de su propia ruta y abre el seguimiento',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: nav,
      home: const Scaffold(body: Text('Inicio')),
    ));

    nav.currentState!.push(MaterialPageRoute(
      builder: (_) => ofertaAceptadaCliente(
        {'nombre': 'Carlos', 'tipoVehiculo': 'camion', 'placa': 'ABC123', 'rating': 4.5},
        seguimiento: (_) => const Scaffold(body: Text('Seguimiento')),
      ),
    ));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.text('Carlos'), findsWidgets);

    await tester.tap(find.text('Ver seguimiento'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Seguimiento'), findsOneWidget);
    expect(find.byType(OfertaAceptadaScreen), findsNothing);

    nav.currentState!.pop();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Inicio'), findsOneWidget);
  });

  testWidgets('conductor sin datos no rompe la pantalla', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ofertaAceptadaCliente(const {}, seguimiento: (_) => const SizedBox()),
    ));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.byType(OfertaAceptadaScreen), findsOneWidget);
  });
}
