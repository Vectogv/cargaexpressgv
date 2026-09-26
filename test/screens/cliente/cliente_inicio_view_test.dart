import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cargaexpress/screens/cliente/cliente_inicio_view.dart';

class _Llamadas {
  int nuevo = 0, seguimiento = 0, historial = 0, perfil = 0, soporte = 0, reintentar = 0;
  final vistos = <Map<String, dynamic>>[];
}

Future<_Llamadas> _pump(
  WidgetTester tester, {
  Map<String, dynamic>? activo,
  List<Map<String, dynamic>> recientes = const [],
  bool cargando = false,
  bool errorActivo = false,
  bool errorRecientes = false,
  Size size = const Size(360, 740),
}) async {
  final l = _Llamadas();
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: ClienteInicioView(
        nombre: 'Ana María',
        cargando: cargando,
        errorActivo: errorActivo,
        viajeActivo: activo,
        recientes: recientes,
        cargandoRecientes: false,
        errorRecientes: errorRecientes,
        onNuevoEnvio: () => l.nuevo++,
        onVerSeguimiento: () => l.seguimiento++,
        onVerViaje: l.vistos.add,
        onHistorial: () => l.historial++,
        onPerfil: () => l.perfil++,
        onSoporte: () => l.soporte++,
        onReintentar: () => l.reintentar++,
        onRefresh: () async {},
      ),
    ),
  ));
  return l;
}

Map<String, dynamic> _viaje(String id, String estado) => {
      '_id': id,
      'estado': estado,
      'origen': {'direccion': 'Origen $id'},
      'destino': {'direccion': 'Destino $id'},
      'createdAt': '2026-09-20T15:30:00.000Z',
    };

void main() {
  testWidgets('sin viaje activo: saludo, Nuevo envío y estado vacío', (tester) async {
    final l = await _pump(tester);
    expect(find.text('¡Hola, Ana!'), findsOneWidget);
    expect(find.text('Aún no tienes envíos'), findsOneWidget);
    expect(find.byKey(const Key('card_viaje_activo')), findsNothing);

    await tester.tap(find.byKey(const Key('btn_nuevo_envio')));
    expect(l.nuevo, 1);

    await tester.tap(find.text('Mis envíos'));
    await tester.tap(find.text('Perfil'));
    await tester.tap(find.text('Soporte'));
    expect([l.historial, l.perfil, l.soporte], [1, 1, 1]);
  });

  testWidgets('con viaje activo muestra su estado en español y abre el seguimiento', (tester) async {
    final l = await _pump(tester, activo: {
      ..._viaje('a1', 'aceptado'),
      'conductor': {'nombre': 'Carlos Pérez', 'placa': 'ABC123', 'tipoVehiculo': 'Camión'},
    });
    expect(find.text('Conductor asignado'), findsOneWidget);
    expect(find.text('Carlos Pérez'), findsOneWidget);
    expect(find.byKey(const Key('btn_nuevo_envio')), findsNothing);

    await tester.tap(find.byKey(const Key('card_viaje_activo')));
    await tester.tap(find.text('Ver seguimiento'));
    expect(l.seguimiento, 2);
  });

  testWidgets('viaje en disputa: el botón no promete seguimiento', (tester) async {
    await _pump(tester, activo: _viaje('d1', 'disputa'));
    expect(find.text('En disputa'), findsOneWidget);
    expect(find.text('Ver estado del caso'), findsOneWidget);
  });

  testWidgets('envíos recientes abren el detalle y "Ver todos" el historial', (tester) async {
    final l = await _pump(tester, recientes: [_viaje('r1', 'finalizado'), _viaje('r2', 'cancelado')]);
    await tester.scrollUntilVisible(find.text('Origen r2'), 200);
    expect(find.text('Finalizado'), findsOneWidget);
    expect(find.text('Cancelado'), findsOneWidget);

    await tester.tap(find.text('Origen r2'));
    expect(l.vistos.single['_id'], 'r2');

    await tester.tap(find.text('Ver todos'));
    expect(l.historial, 1);
  });

  testWidgets('envíos recientes muestran el precio (final o, si no hay, estimado)', (tester) async {
    await _pump(tester, recientes: [
      {..._viaje('r1', 'finalizado'), 'precioEstimado': 30000, 'precioFinal': 32000},
      {..._viaje('r2', 'buscando_conductor'), 'precioEstimado': '25000.00'},
    ]);
    await tester.scrollUntilVisible(find.text('Origen r2'), 200);
    // precioFinal es el monto real: "$32.000", no el estimado "$30.000".
    expect(find.text('\$32.000'), findsOneWidget);
    expect(find.text('\$30.000'), findsNothing);
    expect(find.text('\$25.000'), findsOneWidget);
  });

  testWidgets('sin precio no muestra nada extra junto a la fecha', (tester) async {
    await _pump(tester, recientes: [_viaje('r1', 'finalizado')]);
    expect(find.textContaining('\$'), findsNothing);
  });

  testWidgets('errores de carga ofrecen reintentar', (tester) async {
    final l = await _pump(tester, errorActivo: true, errorRecientes: true);
    expect(find.textContaining('No pudimos verificar'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('No pudimos cargar tus envíos.'), 200);
    await tester.tap(find.text('Reintentar').last);
    expect(l.reintentar, 1);
  });

  testWidgets('sin desbordes en pantalla pequeña', (tester) async {
    await _pump(
      tester,
      size: const Size(320, 568),
      activo: {
        ..._viaje('a1', 'conductor_en_camino'),
        'conductor': {'nombre': 'Carlos Alberto Pérez Gómez', 'placa': 'ABC123', 'tipoVehiculo': 'Camión 3.5 t'},
      },
      recientes: [_viaje('r1', 'pendiente_confirmacion')],
    );
    expect(tester.takeException(), isNull);
  });
}
