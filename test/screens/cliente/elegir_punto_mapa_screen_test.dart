import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:cargaexpress/screens/cliente/elegir_punto_mapa_screen.dart';

const _inicio = LatLng(2.44, -76.6);

Widget _app({
  required Future<String?> Function(LatLng) dir,
  bool esOrigen = true,
  double escala = 1.0,
  ValueChanged<PuntoElegido?>? alVolver,
}) {
  return MaterialApp(
    builder: (c, w) => MediaQuery(
      data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(escala)),
      child: w!,
    ),
    home: Builder(
      builder: (ctx) => Scaffold(
        body: TextButton(
          onPressed: () async {
            final r = await Navigator.push<PuntoElegido>(
              ctx,
              MaterialPageRoute(
                builder: (_) => ElegirPuntoMapaScreen(
                  esOrigen: esOrigen,
                  inicial: _inicio,
                  origen: esOrigen ? null : const LatLng(2.45, -76.61),
                  direccionDe: dir,
                  buscar: (_) async => const [],
                ),
              ),
            );
            alVolver?.call(r);
          },
          child: const Text('abrir'),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'deshabilitado mientras carga y confirmar devuelve punto y dirección',
    (t) async {
      final c = Completer<String?>();
      PuntoElegido? res;
      await t.pumpWidget(_app(dir: (_) => c.future, alVolver: (r) => res = r));
      await t.tap(find.text('abrir'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await t.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('cargando_direccion')), findsOneWidget);
      expect(
        t
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Confirmar origen'),
            )
            .onPressed,
        isNull,
      );

      await t.pump(const Duration(milliseconds: 700));
      c.complete('Calle 5 # 4-20, Centro, Popayán');
      await t.pumpAndSettle();
      expect(find.text('Calle 5 # 4-20'), findsOneWidget);
      await t.tap(find.text('Confirmar origen'));
      await t.pumpAndSettle();
      expect(res!.direccion, 'Calle 5 # 4-20, Centro, Popayán');
      expect(res!.punto.latitude, closeTo(_inicio.latitude, 0.001));
    },
  );

  testWidgets('destino muestra su etiqueta y botón', (t) async {
    await t.pumpWidget(
      _app(dir: (_) async => 'Carrera 9, Popayán', esOrigen: false),
    );
    await t.tap(find.text('abrir'));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(find.text('DESTINO · ENTREGA'), findsOneWidget);
    expect(find.text('Confirmar destino'), findsOneWidget);
    expect(find.text('¿A dónde lo llevamos?'), findsOneWidget);
  });

  for (final tam in [
    const Size(360, 640),
    const Size(800, 400),
    const Size(800, 1200),
  ]) {
    testWidgets('sin desbordes a $tam con letra 1.3', (t) async {
      t.view.physicalSize = tam;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        _app(
          dir: (_) async =>
              'Calle muy larga de nombre extenso número 123 # 45-67, Barrio Largo, Popayán, Cauca, Colombia',
          escala: 1.3,
          esOrigen: false,
        ),
      );
      await t.tap(find.text('abrir'));
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      expect(t.takeException(), isNull);
      expect(find.text('Confirmar destino'), findsOneWidget);
      // Con el teclado abierto en la búsqueda tampoco desborda.
      t.view.viewInsets = FakeViewPadding(bottom: tam.height * 0.4);
      addTearDown(t.view.resetViewInsets);
      await t.tap(find.byType(TextField));
      await t.pump(const Duration(seconds: 1));
      expect(t.takeException(), isNull);
    });
  }
}
