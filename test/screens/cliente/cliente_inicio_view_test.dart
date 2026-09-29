import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cargaexpress/screens/cliente/cliente_inicio_view.dart';

class _Llamadas {
  int nuevo = 0, seguimiento = 0, historial = 0, confirmar = 0, problema = 0, reintentar = 0;
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
        onConfirmarEntrega: () => l.confirmar++,
        onReportarProblema: () => l.problema++,
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

const _conductor = {'nombre': 'Carlos Pérez', 'placa': 'ABC123', 'tipoVehiculo': 'Camioneta', 'calificacion': 4.8};

void main() {
  test('pasoProgresoViaje sigue los estados del backend', () {
    expect(pasoProgresoViaje('aceptado'), 0);
    expect(pasoProgresoViaje('conductor_llegada'), 0);
    expect(pasoProgresoViaje('en_curso'), 2);
    expect(pasoProgresoViaje('pendiente_confirmacion'), 3);
    expect(pasoProgresoViaje('buscando_conductor'), isNull);
    expect(pasoProgresoViaje('disputa'), isNull);
  });

  testWidgets('sin viaje activo: saludo, Nuevo envío y estados vacíos', (tester) async {
    final l = await _pump(tester);
    expect(find.text('¡Hola, Ana!'), findsOneWidget);
    expect(find.text('¿Qué vas a enviar hoy?'), findsOneWidget);
    expect(find.text('No tienes envíos en curso'), findsOneWidget);
    expect(find.text('Aún no tienes envíos'), findsOneWidget);
    expect(find.byKey(const Key('card_viaje_activo')), findsNothing);
    expect(find.text('Ver detalle ›'), findsNothing);

    await tester.tap(find.byKey(const Key('btn_nuevo_envio')));
    expect(l.nuevo, 1);
  });

  testWidgets('conductor asignado: chip, conductor, progreso y PIN; abre el seguimiento', (tester) async {
    final l = await _pump(tester, activo: {..._viaje('a1', 'aceptado'), 'conductor': _conductor, 'pinEntrega': '4821'});
    expect(find.text('Conductor asignado'), findsOneWidget);
    expect(find.text('Carlos Pérez'), findsOneWidget);
    expect(find.text('ABC123'), findsOneWidget);
    expect(find.text('★ 4.8 · Camioneta'), findsOneWidget);
    expect(find.byKey(const Key('progreso_viaje')), findsOneWidget);
    expect(find.text('4821'), findsOneWidget);
    // Con un viaje activo el backend rechaza otro (409): no se ofrece.
    expect(find.byKey(const Key('btn_nuevo_envio')), findsNothing);

    await tester.tap(find.byKey(const Key('card_viaje_activo')));
    await tester.tap(find.text('Ver detalle ›'));
    expect(l.seguimiento, 2);
  });

  testWidgets('envío en camino: título y carga de la solicitud', (tester) async {
    await _pump(tester, activo: {..._viaje('a1', 'en_curso'), 'conductor': _conductor, 'carga': 'Caja mediana', 'pinEntrega': '1234'});
    expect(find.text('Tu envío va en camino'), findsOneWidget);
    expect(find.text('Tu envío en camino'), findsOneWidget);
    expect(find.text('Caja mediana'), findsOneWidget);
    expect(find.text('1234'), findsOneWidget);
  });

  testWidgets('buscando conductor: botón Ver ofertas', (tester) async {
    final l = await _pump(tester, activo: _viaje('b1', 'buscando_conductor'));
    expect(find.byKey(const Key('progreso_viaje')), findsNothing);
    await tester.tap(find.text('Ver ofertas'));
    expect(l.seguimiento, 1);
  });

  testWidgets('entrega por confirmar: aviso, sin PIN, y los dos botones', (tester) async {
    final l = await _pump(tester, activo: {
      ..._viaje('p1', 'pendiente_confirmacion'),
      'conductor': _conductor,
      'pinEntrega': '4821',
      'precioFinal': 45000,
    });
    expect(find.text('Tu envío llegó al destino'), findsOneWidget);
    expect(find.text('Confirma tu entrega'), findsOneWidget);
    expect(find.textContaining('Carlos Pérez marcó la entrega'), findsOneWidget);
    expect(find.textContaining('un moderador revisará'), findsOneWidget);
    expect(find.text('\$45.000'), findsOneWidget);
    // El PIN ya se usó: no se muestra.
    expect(find.text('4821'), findsNothing);

    await tester.tap(find.byKey(const Key('btn_confirmar_entrega_inicio')));
    await tester.tap(find.byKey(const Key('btn_problema_entrega')));
    expect([l.confirmar, l.problema], [1, 1]);
  });

  testWidgets('viaje en disputa: el botón no promete seguimiento', (tester) async {
    await _pump(tester, activo: _viaje('d1', 'disputa'));
    expect(find.text('En disputa'), findsOneWidget);
    expect(find.text('Ver estado del caso'), findsOneWidget);
    expect(find.text('Ver detalle ›'), findsNothing);
  });

  testWidgets('sólo el último envío, abre el detalle y "Ver todos" el historial', (tester) async {
    final l = await _pump(tester, recientes: [_viaje('r1', 'finalizado'), _viaje('r2', 'cancelado')]);
    await tester.scrollUntilVisible(find.byKey(const Key('tile_ultimo_envio')), 200);
    expect(find.text('Finalizado'), findsOneWidget);
    expect(find.textContaining('Origen r2'), findsNothing);

    await tester.tap(find.byKey(const Key('tile_ultimo_envio')));
    expect(l.vistos.single['_id'], 'r1');

    await tester.tap(find.text('Ver todos'));
    expect(l.historial, 1);
  });

  testWidgets('el último envío muestra el precio final (no el estimado)', (tester) async {
    await _pump(tester, recientes: [
      {..._viaje('r1', 'finalizado'), 'precioEstimado': 30000, 'precioFinal': 32000},
    ]);
    await tester.scrollUntilVisible(find.byKey(const Key('tile_ultimo_envio')), 200);
    expect(find.textContaining('\$32.000'), findsOneWidget);
    expect(find.textContaining('\$30.000'), findsNothing);
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
        ..._viaje('a1', 'pendiente_confirmacion'),
        'conductor': {'nombre': 'Carlos Alberto Pérez Gómez', 'placa': 'ABC123', 'tipoVehiculo': 'Camión 3.5 t'},
        'carga': 'Nevera grande de dos puertas con empaque original',
        'precioFinal': '1250000.00',
      },
      recientes: [_viaje('r1', 'pendiente_confirmacion')],
    );
    expect(tester.takeException(), isNull);
  });
}
