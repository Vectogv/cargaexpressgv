import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cargaexpress/models/trip.dart';
import 'package:cargaexpress/screens/cliente/busqueda_conductor_view.dart';

Trip _trip({Map<String, dynamic>? busqueda}) => Trip.fromJson({
      '_id': 't1',
      'estado': 'buscando',
      'origen': {'direccion': 'Calle 10 # 43-20, Medellín', 'lat': 6.2, 'lng': -75.5},
      'destino': {'direccion': 'Carrera 70, Envigado', 'lat': 6.17, 'lng': -75.59},
      'descripcion': '3 cajas medianas',
      'precioEstimado': 150000,
      if (busqueda != null) 'busqueda': busqueda,
    });

const _textoFijo = 'Enviamos tu solicitud a los conductores cercanos. Te avisaremos apenas alguno te haga una oferta.';

Future<void> _pump(
  WidgetTester tester, {
  int ofertas = 0,
  int cercanos = 0,
  bool cancelando = false,
  VoidCallback? onVerOfertas,
  VoidCallback? onCancelar,
  Map<String, dynamic>? busqueda,
  ValueChanged<int>? onSubirPrecio,
  VoidCallback? onSeguirEsperando,
  VoidCallback? onProgramar,
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
        trip: _trip(busqueda: busqueda),
        mapa: const ColoredBox(color: Colors.grey, key: Key('mapa')),
        vehiculosCercanos: cercanos,
        ofertas: ofertas,
        cancelando: cancelando,
        inicioBusqueda: DateTime.now().subtract(const Duration(minutes: 2, seconds: 5)),
        onVerOfertas: onVerOfertas ?? () {},
        onCancelar: onCancelar ?? () {},
        onSubirPrecio: onSubirPrecio,
        onSeguirEsperando: onSeguirEsperando,
        onProgramar: onProgramar,
      ),
    ),
  ));
}

void main() {
  testWidgets('muestra estado, tiempo, radio y resumen del viaje', (tester) async {
    await _pump(tester);

    expect(find.text('Buscando conductor…'), findsOneWidget);
    expect(find.text('Buscando conductor'), findsOneWidget); // barra superior flotante
    expect(find.byKey(const Key('mapa')), findsOneWidget);
    // Con la máquina cargada puede pasar un segundo entre el test y el widget.
    expect(find.textContaining(RegExp(r'^02:0[56]$')), findsOneWidget);
    expect(find.text('Aún no hay vehículos cerca, seguimos buscando'), findsOneWidget);
    expect(find.text('Calle 10 # 43-20, Medellín'), findsOneWidget);
    expect(find.text('Carrera 70, Envigado'), findsOneWidget);
    expect(find.text('3 cajas medianas'), findsOneWidget);
    expect(find.text('\$150.000 COP'), findsOneWidget);
    expect(find.byKey(const Key('card_ofertas')), findsNothing);
    expect(find.text('Servicio para ya'), findsOneWidget);
  });

  testWidgets('una reserva muestra la fecha y hora programadas, no "para ya"', (tester) async {
    tester.view.physicalSize = const Size(360, 640) * 3;
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(bottom: 48 * 3.0);
    addTearDown(tester.view.reset);
    final reserva = Trip.fromJson({
      '_id': 't2',
      'estado': 'buscando',
      'origen': {'direccion': 'Calle 10 # 43-20, Medellín', 'lat': 6.2, 'lng': -75.5},
      'destino': {'direccion': 'Carrera 70, Envigado', 'lat': 6.17, 'lng': -75.59},
      'precioEstimado': 150000,
      'tipoProgramacion': 'programada',
      'fechaProgramada': '2026-09-26',
      'horaProgramada': '18:03',
    });
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BusquedaConductorView(
          trip: reserva,
          mapa: const ColoredBox(color: Colors.grey, key: Key('mapa')),
          vehiculosCercanos: 0,
          ofertas: 0,
          cancelando: false,
          inicioBusqueda: DateTime.now(),
          onVerOfertas: () {},
          onCancelar: () {},
        ),
      ),
    ));
    expect(find.text('Servicio para ya'), findsNothing);
    expect(find.text('Reserva: 26 sep, 6:03 p. m.'), findsOneWidget);
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
    expect(find.text('3 ofertas recibidas'), findsOneWidget);
    expect(find.text('Ver ofertas'), findsOneWidget);
    expect(find.text('4 vehículos disponibles a menos de 2 km'), findsOneWidget);
  });

  testWidgets('las ofertas recibidas abren el listado', (tester) async {
    var abiertas = 0;
    await _pump(tester, ofertas: 2, onVerOfertas: () => abiertas++);
    expect(find.text('2 ofertas recibidas'), findsOneWidget);
    await tester.tap(find.byKey(const Key('card_ofertas')));
    expect(abiertas, 1);
  });

  testWidgets('cancelar pide un motivo y devuelve motivo + comentario', (tester) async {
    final resultados = <String?>[];
    await _pump(tester, onCancelar: () {});
    final ctx = tester.element(find.byType(BusquedaConductorView));

    // Seguir buscando: no cancela.
    final f1 = elegirMotivoCancelacionBusqueda(ctx).then(resultados.add);
    await tester.pumpAndSettle();
    expect(find.text('¿Cancelar la búsqueda?'), findsOneWidget);
    await tester.ensureVisible(find.text('Seguir buscando'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seguir buscando'));
    await tester.pumpAndSettle();
    await f1.timeout(const Duration(seconds: 1));

    // Sin motivo elegido el botón está deshabilitado.
    final f2 = elegirMotivoCancelacionBusqueda(ctx).then(resultados.add);
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byKey(const Key('btn_confirmar_cancelacion'))).onPressed, isNull);

    await tester.tap(find.text('Error en la dirección'));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('campo_comentario_cancelacion')), 'Puse mal el barrio');
    await tester.ensureVisible(find.byKey(const Key('btn_confirmar_cancelacion')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('btn_confirmar_cancelacion')));
    await tester.pumpAndSettle();
    await f2.timeout(const Duration(seconds: 1));

    expect(resultados, [null, 'Error en la dirección: Puse mal el barrio']);
  });

  testWidgets('mientras cancela el botón queda deshabilitado', (tester) async {
    await _pump(tester, cancelando: true);
    expect(find.text('Cancelando…'), findsOneWidget);
    final btn = tester.widget<OutlinedButton>(find.byKey(const Key('btn_cancelar_busqueda')));
    expect(btn.onPressed, isNull);
  });

  // ---- Escalera de acompañamiento (objeto `busqueda` que arma el servidor) ----

  testWidgets('sin busqueda se ve el texto fijo de siempre', (tester) async {
    await _pump(tester);
    expect(find.text(_textoFijo), findsOneWidget);
    expect(find.byKey(const Key('btn_subir_precio')), findsNothing);
    expect(find.byKey(const Key('btn_seguir_esperando')), findsNothing);
  });

  testWidgets('el encabezado muestra el mensaje de cada etapa', (tester) async {
    for (final etapa in ['publicado', 'ampliada', 'sugerencia', 'cierre']) {
      await _pump(tester, busqueda: {
        'etapa': etapa,
        'mensaje': 'Mensaje de $etapa',
        'precioSugerido': etapa == 'sugerencia' ? {'min': 170000, 'max': 190000} : null,
        'cierreHasta': null,
      });
      expect(find.text('Mensaje de $etapa'), findsOneWidget, reason: etapa);
      expect(find.text(_textoFijo), findsNothing, reason: etapa);
    }
  });

  testWidgets('con ofertas, el conteo de ofertas gana al mensaje de la etapa', (tester) async {
    await _pump(tester, ofertas: 2, busqueda: {'etapa': 'ampliada', 'mensaje': 'Ampliando'});
    expect(find.text('Ampliando'), findsNothing);
    expect(find.textContaining('2 ofertas'), findsOneWidget);
  });

  testWidgets('sugerencia: Subir a \$X manda el mínimo y Mantener oculta la tarjeta', (tester) async {
    final subidas = <int>[];
    await _pump(tester, onSubirPrecio: subidas.add, busqueda: {
      'etapa': 'sugerencia',
      'mensaje': 'Los conductores piden un poco más',
      'precioSugerido': {'min': 170000, 'max': 190000},
    });
    expect(find.text('Los viajes parecidos se pagan entre \$170.000 y \$190.000'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('btn_subir_precio')));
    await tester.pumpAndSettle();
    expect(find.text('Subir a \$170.000'), findsOneWidget);
    await tester.tap(find.byKey(const Key('btn_subir_precio')));
    expect(subidas, [170000]);

    await tester.tap(find.byKey(const Key('btn_mantener_precio')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('btn_subir_precio')), findsNothing);
    // El mensaje del encabezado sigue: solo se oculta la tarjeta.
    expect(find.text('Los conductores piden un poco más'), findsOneWidget);
  });

  testWidgets('cierre: los dos botones llaman a sus callbacks', (tester) async {
    int seguir = 0, programar = 0;
    await _pump(
      tester,
      onSeguirEsperando: () => seguir++,
      onProgramar: () => programar++,
      busqueda: {'etapa': 'cierre', 'mensaje': 'Aún no hay conductor', 'cierreHasta': '2026-10-07T20:00:00.000Z'},
    );
    expect(find.text('¿Qué quieres hacer?'), findsOneWidget);

    for (final k in ['btn_seguir_esperando', 'btn_programar_mas_tarde']) {
      await tester.ensureVisible(find.byKey(Key(k)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key(k)));
    }
    expect([seguir, programar], [1, 1]);
    // Cancelar ya está abajo ("Cancelar búsqueda"): la tarjeta no lo repite.
    expect(find.byKey(const Key('btn_cancelar_sin_costo')), findsNothing);
  });

  testWidgets('mientras hay una acción en curso, los botones de la escalera se deshabilitan', (tester) async {
    await _pump(tester, cancelando: true, onSeguirEsperando: () {}, busqueda: {'etapa': 'cierre', 'mensaje': 'x'});
    // "Cancelando…" tiene un spinner infinito: nada de pumpAndSettle.
    await tester.ensureVisible(find.byKey(const Key('btn_seguir_esperando')));
    await tester.pump();
    final boton = find.descendant(of: find.byKey(const Key('btn_seguir_esperando')), matching: find.byType(FilledButton));
    expect(tester.widget<FilledButton>(boton).onPressed, isNull);
  });
}
