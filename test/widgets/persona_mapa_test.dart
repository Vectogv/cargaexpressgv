import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:cargaexpress/widgets/persona_mapa.dart';

void main() {
  group('PersonaMapa', () {
    test('la etiqueta es el primer nombre, o "Cliente" si no hay', () {
      expect(PersonaMapa.etiquetaDe('Ana María Pérez'), 'Ana');
      expect(PersonaMapa.etiquetaDe('  Luis '), 'Luis');
      expect(PersonaMapa.etiquetaDe(''), 'Cliente');
      expect(PersonaMapa.etiquetaDe(null), 'Cliente');
    });

    test('la caja del marcador crece con la etiqueta y la figura queda centrada', () {
      expect(PersonaMapa.caja(40), const Size(40, 40));
      final conEtiqueta = PersonaMapa.caja(40, conEtiqueta: true);
      expect(conEtiqueta.width, greaterThanOrEqualTo(120));
      // Espacio simétrico arriba y abajo: el centro sigue siendo la figura.
      expect(conEtiqueta.height, 40 + 2 * 24);
    });

    testWidgets('dibuja la figura con el pintor de persona y la etiqueta', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Center(child: PersonaMapa(etiqueta: 'Ana', tamano: 44)),
      ));
      final pintado = tester.widget<CustomPaint>(find.byWidgetPredicate((w) => w is CustomPaint && w.painter is PintorPersona));
      final pintor = pintado.painter! as PintorPersona;
      expect(pintor.color, colorPersonaCliente);
      expect(pintor.halo, isTrue);
      expect(find.text('Ana'), findsOneWidget);
      expect(tester.getSize(find.byType(PersonaMapa)), PersonaMapa.caja(44, conEtiqueta: true));
    });

    testWidgets('sin etiqueta ocupa sólo la figura', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Center(child: PersonaMapa(tamano: 40))));
      expect(find.byType(Text), findsNothing);
      expect(tester.getSize(find.byType(PersonaMapa)), const Size(40, 40));
    });

    testWidgets('se puede usar como marcador de un FlutterMap', (tester) async {
      const punto = LatLng(2.44188, -76.60631);
      final caja = PersonaMapa.caja(40, conEtiqueta: true);
      await tester.pumpWidget(MaterialApp(
        home: SizedBox(
          width: 400,
          height: 400,
          child: FlutterMap(
            options: const MapOptions(initialCenter: punto, initialZoom: 16),
            children: [
              MarkerLayer(markers: [
                Marker(point: punto, width: caja.width, height: caja.height, child: const PersonaMapa(etiqueta: 'Cliente')),
              ]),
            ],
          ),
        ),
      ));
      await tester.pump();
      expect(find.byType(PersonaMapa), findsOneWidget);
      expect(find.text('Cliente'), findsOneWidget);
      // La figura queda centrada sobre la coordenada (centro del mapa).
      final centro = tester.getCenter(find.byType(PersonaMapa));
      final mapa = tester.getCenter(find.byType(FlutterMap));
      expect((centro - mapa).distance, lessThan(1));
    });

    test('el pintor se repinta sólo si cambian color o halo', () {
      const a = PintorPersona(color: Colors.green);
      expect(a.shouldRepaint(const PintorPersona(color: Colors.green)), isFalse);
      expect(a.shouldRepaint(const PintorPersona(color: Colors.blue)), isTrue);
      expect(a.shouldRepaint(const PintorPersona(color: Colors.green, halo: false)), isTrue);
    });
  });
}
