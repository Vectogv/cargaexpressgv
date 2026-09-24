import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:cargaexpress/widgets/mapa_viaje.dart';

void main() {
  group('MapaViaje.puntoDe', () {
    test('lee lat/lng numéricos o en texto', () {
      expect(MapaViaje.puntoDe({'lat': 2.44, 'lng': -76.6}), const LatLng(2.44, -76.6));
      expect(MapaViaje.puntoDe({'lat': '2.44', 'lng': '-76.6'}), const LatLng(2.44, -76.6));
    });

    test('sin coordenadas o en 0,0 no hay punto', () {
      expect(MapaViaje.puntoDe(null), isNull);
      expect(MapaViaje.puntoDe({'direccion': 'Calle 5'}), isNull);
      expect(MapaViaje.puntoDe({'lat': 0, 'lng': 0}), isNull);
      expect(MapaViaje.punto(0, 0), isNull);
    });
  });

  testWidgets('con coordenadas dibuja un mapa real con sus marcadores', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: SizedBox(
        height: 220,
        child: MapaViaje(origen: LatLng(2.44, -76.6), destino: LatLng(2.46, -76.58), vehiculo: LatLng(2.45, -76.59)),
      ),
    ));
    await tester.pump(); // la cámara se ajusta tras el primer layout
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byIcon(Icons.location_on), findsOneWidget);
    expect(find.byIcon(Icons.local_shipping), findsOneWidget);
  });

  testWidgets('sin coordenadas no inventa un mapa', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox(height: 220, child: MapaViaje())));
    expect(find.byType(FlutterMap), findsNothing);
    expect(find.byIcon(Icons.map_outlined), findsOneWidget);
  });

  group('ruta dibujada', () {
    testWidgets('sin ruta no se dibuja ninguna línea', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: SizedBox(
          height: 220,
          child: MapaViaje(origen: LatLng(2.44, -76.6), destino: LatLng(2.46, -76.58)),
        ),
      ));
      await tester.pump();
      expect(find.byType(PolylineLayer), findsNothing);
    });

    testWidgets('ruta aproximada (línea recta de respaldo) se dibuja punteada y sin borde', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: SizedBox(
          height: 220,
          child: MapaViaje(
            origen: LatLng(2.44, -76.6),
            destino: LatLng(2.46, -76.58),
            ruta: [LatLng(2.44, -76.6), LatLng(2.46, -76.58)],
            rutaAproximada: true,
          ),
        ),
      ));
      await tester.pump();

      final layer = tester.widget<PolylineLayer>(find.byType(PolylineLayer));
      final poly = layer.polylines.single;
      expect(poly.borderStrokeWidth, 0);
      expect(poly.pattern, StrokePattern.dashed(segments: const [12, 10]));
      expect(poly.pattern, isNot(const StrokePattern.solid()));
    });

    testWidgets('ruta real (del servicio de rutas) se dibuja sólida y con borde', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: SizedBox(
          height: 220,
          child: MapaViaje(
            origen: LatLng(2.44, -76.6),
            destino: LatLng(2.46, -76.58),
            ruta: [LatLng(2.44, -76.6), LatLng(2.45, -76.59), LatLng(2.46, -76.58)],
          ),
        ),
      ));
      await tester.pump();

      final layer = tester.widget<PolylineLayer>(find.byType(PolylineLayer));
      final poly = layer.polylines.single;
      expect(poly.borderStrokeWidth, 2);
      expect(poly.pattern, const StrokePattern.solid());
    });
  });

  testWidgets('un gesto del usuario (arrastrar el mapa) avisa con onGestoUsuario', (tester) async {
    var avisos = 0;
    await tester.pumpWidget(MaterialApp(
      home: SizedBox(
        height: 400,
        width: 400,
        child: MapaViaje(
          origen: const LatLng(2.44, -76.6),
          destino: const LatLng(2.46, -76.58),
          onGestoUsuario: () => avisos++,
        ),
      ),
    ));
    await tester.pump();

    await tester.drag(find.byType(FlutterMap), const Offset(-80, -40));
    await tester.pump();

    expect(avisos, greaterThan(0));
  });
}
