import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cargaexpress/models/trip.dart';
import 'package:cargaexpress/screens/cliente/seguimiento_viaje_view.dart';

Trip _trip({Map<String, dynamic>? conductor}) => Trip.fromJson({
      '_id': 't1',
      'estado': 'en_curso',
      'origen': {'direccion': 'Calle 10 # 43-20, Medellín', 'lat': 6.2, 'lng': -75.5},
      'destino': {'direccion': 'Carrera 70, Envigado', 'lat': 6.17, 'lng': -75.59},
      'descripcion': '3 cajas medianas',
      'precioEstimado': 150000,
      if (conductor != null) 'conductor': conductor,
    });

Future<void> _pump(
  WidgetTester tester, {
  Trip? trip,
  String calificacion = 'Nuevo',
  VoidCallback? onChat,
  VoidCallback? onRecentrar,
  VoidCallback? onCancelar,
  String textoCancelar = 'Cancelar viaje',
  String distancia = '--',
  Size size = const Size(360, 800),
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  tester.view.padding = const FakeViewPadding(bottom: 48 * 3.0);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SeguimientoViajeView(
        titulo: 'Conductor asignado',
        mapa: const ColoredBox(color: Colors.grey, key: Key('mapa')),
        estado: 'Conductor asignado',
        distancia: distancia,
        distanciaEtiqueta: 'Del conductor al punto de recogida',
        trip: trip ?? _trip(),
        calificacion: calificacion,
        onRecentrar: onRecentrar,
        onChat: onChat,
        onLlamar: () {},
        onReportar: () {},
        onSos: () {},
        onCancelar: onCancelar,
        textoCancelar: textoCancelar,
      ),
    ),
  ));
}

void main() {
  testWidgets('muestra placa, tipo de vehículo y calificación del conductor', (tester) async {
    await _pump(
      tester,
      trip: _trip(conductor: {
        '_id': 'c1',
        'nombre': 'Carlos Pérez',
        'placa': 'abc123',
        'tipoVehiculo': 'camion_estacas',
      }),
      calificacion: '4.8',
      // La fuente de test (Ahem) es más ancha que la real: fila conductor
      // (nombre + calificación + tipo + placa) necesita más ancho para caber.
      size: const Size(480, 800),
    );

    expect(find.text('Carlos Pérez'), findsOneWidget);
    expect(find.text('ABC123'), findsOneWidget);
    expect(find.text('Camion estacas'), findsOneWidget);
    expect(find.text('4.8'), findsOneWidget);
  });

  testWidgets('conductor sin calificaciones muestra "Nuevo" en vez de un número inventado', (tester) async {
    await _pump(
      tester,
      trip: _trip(conductor: {'_id': 'c1', 'nombre': 'Carlos'}),
      calificacion: 'Nuevo',
    );

    expect(find.text('Nuevo'), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsOneWidget);
  });

  testWidgets('sin conductor asignado no hay placa, tipo de vehículo ni fila de calificación', (tester) async {
    await _pump(tester, trip: _trip(), calificacion: 'Nuevo');

    expect(find.text('Conductor'), findsOneWidget); // nombre por defecto
    expect(find.text('Nuevo'), findsNothing);
    expect(find.byIcon(Icons.star_rounded), findsNothing);
  });

  testWidgets('el botón de chat está oculto cuando el estado no lo permite (onChat null)', (tester) async {
    await _pump(tester, onChat: null);
    expect(find.byKey(const Key('btn_chat_conductor')), findsNothing);
  });

  testWidgets('el botón de chat aparece y dispara el callback cuando el estado lo permite', (tester) async {
    var taps = 0;
    await _pump(tester, onChat: () => taps++);

    expect(find.byKey(const Key('btn_chat_conductor')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('btn_chat_conductor')));
    await tester.tap(find.byKey(const Key('btn_chat_conductor')));
    expect(taps, 1);
  });

  testWidgets('el texto de cancelar es el que decide la pantalla llamadora según el estado', (tester) async {
    await _pump(tester, textoCancelar: 'Cancelar viaje');
    expect(find.text('Cancelar viaje'), findsOneWidget);
    expect(find.text('Solicitar cancelación'), findsNothing);

    await _pump(tester, textoCancelar: 'Solicitar cancelación');
    expect(find.text('Solicitar cancelación'), findsOneWidget);
    expect(find.text('Cancelar viaje'), findsNothing);
  });

  testWidgets('con onCancelar null el botón de cancelar queda deshabilitado, no oculto', (tester) async {
    await _pump(tester, onCancelar: null);
    await tester.ensureVisible(find.byKey(const Key('btn_cancelar_viaje')));
    final btn = tester.widget<TextButton>(find.byKey(const Key('btn_cancelar_viaje')));
    expect(btn.onPressed, isNull);
  });

  testWidgets('origen, destino y precio del viaje se muestran en los detalles', (tester) async {
    await _pump(tester);

    expect(find.text('Calle 10 # 43-20, Medellín'), findsOneWidget);
    expect(find.text('Carrera 70, Envigado'), findsOneWidget);
    expect(find.text('3 cajas medianas'), findsOneWidget);
    expect(find.text('\$150.000 COP'), findsOneWidget);
  });

  testWidgets('la distancia se muestra tal cual la envía el backend, o "--" si no hay dato real', (tester) async {
    await _pump(tester, distancia: '--');
    expect(find.byKey(const Key('distancia_rastreo')), findsOneWidget);
    expect(find.text('--'), findsOneWidget);

    await _pump(tester, distancia: '350 m');
    expect(find.text('350 m'), findsOneWidget);
    expect(find.text('--'), findsNothing);
  });

  testWidgets('el botón recentrar sólo aparece con callback y lo dispara al tocarlo', (tester) async {
    await _pump(tester, onRecentrar: null);
    expect(find.byKey(const Key('btn_recentrar')), findsNothing);

    var recentrados = 0;
    await _pump(tester, onRecentrar: () => recentrados++);
    expect(find.byKey(const Key('btn_recentrar')), findsOneWidget);
    await tester.tap(find.byKey(const Key('btn_recentrar')));
    expect(recentrados, 1);
  });
}
