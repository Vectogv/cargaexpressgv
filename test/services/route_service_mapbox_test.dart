import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:cargaexpress/screens/cliente/llegada_al_destino_screen.dart';
import 'package:cargaexpress/services/route_service.dart';
import 'package:cargaexpress/widgets/media_image.dart';

void main() {
  group('RouteService.parseRutaMapbox', () {
    test('convierte las coordenadas GeoJSON [lng, lat] en puntos', () {
      final puntos = RouteService.parseRutaMapbox({
        'routes': [
          {
            'geometry': {
              'coordinates': [
                [-76.60631, 2.44188],
                [-76.6, 2.45],
                [-76.5915, 2.46129],
              ],
            },
          },
        ],
      });
      expect(puntos, const [LatLng(2.44188, -76.60631), LatLng(2.45, -76.6), LatLng(2.46129, -76.5915)]);
    });

    test('sin rutas o con geometría inválida devuelve null', () {
      expect(RouteService.parseRutaMapbox(null), isNull);
      expect(RouteService.parseRutaMapbox({'routes': []}), isNull);
      expect(RouteService.parseRutaMapbox({'code': 'NoRoute'}), isNull);
      expect(
        RouteService.parseRutaMapbox({
          'routes': [
            {
              'geometry': {
                'coordinates': [
                  [-76.6, 2.4],
                ],
              },
            },
          ],
        }),
        isNull,
      );
    });
  });

  group('LlegadaAlDestinoScreen: foto de evidencia', () {
    Widget pantalla({Future<String?> Function()? cargarFoto}) => MaterialApp(
          home: LlegadaAlDestinoScreen(
            conductor: const {},
            trip: const {},
            onVerDetalle: () {},
            cargarFoto: cargarFoto,
          ),
        );

    testWidgets('si el viaje en memoria no la trae, la consulta al backend', (tester) async {
      await tester.pumpWidget(pantalla(cargarFoto: () async => '/storage/uploads/delivery-19.png'));
      await tester.pump();
      await tester.pump();
      // (sin red en tests, MediaImage muestra su placeholder mientras carga)
      expect(find.byType(MediaImage), findsOneWidget);
    });

    testWidgets('si el backend tampoco la tiene (o falla), lo dice', (tester) async {
      await tester.pumpWidget(pantalla(cargarFoto: () async => throw Exception('red')));
      await tester.pump();
      await tester.pump();
      expect(find.text('El conductor no adjuntó foto'), findsOneWidget);
    });
  });
}
