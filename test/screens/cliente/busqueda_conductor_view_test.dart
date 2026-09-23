import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cargaexpress/models/trip.dart';
import 'package:cargaexpress/screens/cliente/busqueda_conductor_view.dart';

Trip _trip() => Trip.fromJson({
      '_id': 't1',
      'estado': 'buscando',
      'origen': {'direccion': 'Calle 10 # 43-20, Medellín', 'lat': 6.2, 'lng': -75.5},
      'destino': {'direccion': 'Carrera 70, Envigado', 'lat': 6.17, 'lng': -75.59},
      'descripcion': '3 cajas medianas',
      'precioEstimado': 150000,
    });

Future<void> _pump(
  WidgetTester tester, {
  int ofertas = 0,
  int cercanos = 0,
  bool cancelando = false,
  VoidCallback? onVerOfertas,
  VoidCallback? onCancelar,
  Size size = const Size(360, 640),
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  // Barra de navegación de Android (gestos/botones) abajo.
  tester.view.padding = const FakeViewPadding(bottom: 48 * 3.0);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: BusquedaConductorView(
        trip: _trip(),
        mapa: const ColoredBox(color: Colors.grey, key: Key('mapa')),
        vehiculosCercanos: cercanos,
        ofertas: ofertas,
        cancelando: cancelando,
        inicioBusqueda: DateTime.now().subtract(const Duration(minutes: 2, seconds: 5)),
        onVerOfertas: onVerOfertas ?? () {},
        onCancelar: onCancelar ?? () {},
      ),
    ),
  ));
}

void main() {
  testWidgets('muestra estado, tiempo, radio y resumen del viaje', (tester) async {
    await _pump(tester);

    expect(find.text('Buscando conductor disponible'), findsOneWidget);
    expect(find.text('02:05'), findsOneWidget);
    expect(find.text('Sin vehículos disponibles a menos de 2 km'), findsOneWidget);
    expect(find.text('Calle 10 # 43-20, Medellín'), findsOneWidget);
    expect(find.text('Carrera 70, Envigado'), findsOneWidget);
    expect(find.text('3 cajas medianas'), findsOneWidget);
    expect(find.text('\$150.000 COP'), findsOneWidget);
    expect(find.byKey(const Key('card_ofertas')), findsNothing);
  });

  testWidgets('el botón cancelar queda por encima de la barra de navegación', (tester) async {
    await _pump(tester);
    final boton = tester.getRect(find.byKey(const Key('btn_cancelar_busqueda')));
    expect(boton.bottom, lessThanOrEqualTo(640 - 48));
    expect(boton.left, greaterThanOrEqualTo(16));
    expect(tester.takeException(), isNull);
  });

  testWidgets('sin desbordes en pantalla pequeña con ofertas', (tester) async {
    await _pump(tester, ofertas: 3, cercanos: 4, size: const Size(320, 540));
    expect(tester.takeException(), isNull);
    expect(find.text('Tienes ofertas de conductores'), findsOneWidget);
    expect(find.text('4 vehículos disponibles a menos de 2 km'), findsOneWidget);
  });

  testWidgets('las ofertas recibidas abren el listado', (tester) async {
    var abiertas = 0;
    await _pump(tester, ofertas: 2, onVerOfertas: () => abiertas++);
    expect(find.text('2 ofertas recibidas'), findsOneWidget);
    await tester.tap(find.byKey(const Key('card_ofertas')));
    expect(abiertas, 1);
  });

  testWidgets('cancelar pide confirmación', (tester) async {
    final confirmado = <bool>[];
    await _pump(tester, onCancelar: () {});
    final ctx = tester.element(find.byType(BusquedaConductorView));

    final f1 = confirmarCancelarBusqueda(ctx).then(confirmado.add);
    await tester.pumpAndSettle();
    expect(find.text('¿Cancelar la búsqueda?'), findsOneWidget);
    await tester.tap(find.text('Seguir buscando'));
    await tester.pumpAndSettle();
    await f1;

    final f2 = confirmarCancelarBusqueda(ctx).then(confirmado.add);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sí, cancelar'));
    await tester.pumpAndSettle();
    await f2;

    expect(confirmado, [false, true]);
  });

  testWidgets('mientras cancela el botón queda deshabilitado', (tester) async {
    await _pump(tester, cancelando: true);
    expect(find.text('Cancelando…'), findsOneWidget);
    final btn = tester.widget<OutlinedButton>(find.byKey(const Key('btn_cancelar_busqueda')));
    expect(btn.onPressed, isNull);
  });
}
