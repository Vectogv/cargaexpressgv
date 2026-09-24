import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:cargaexpress/contracts/trip_status.dart';
import 'package:cargaexpress/screens/cliente/rastreo_screen.dart';
import 'package:cargaexpress/widgets/capa_vehiculos.dart';
import 'package:cargaexpress/widgets/mapa_viaje.dart';
import 'package:cargaexpress/widgets/vehiculo_mapa.dart';

const _base = LatLng(2.4448, -76.6147);

/// Punto a [m] metros al este de [_base].
LatLng _alEste(double m) => LatLng(_base.latitude, _base.longitude + m / (111320 * 0.99909));

Widget _mapa(List<VehiculoEnMapa> vehiculos) => MaterialApp(
      home: SizedBox(
        width: 400,
        height: 400,
        child: FlutterMap(
          options: const MapOptions(initialCenter: _base, initialZoom: 16),
          children: [CapaVehiculos(vehiculos: vehiculos)],
        ),
      ),
    );

VehiculoMapa _unico(WidgetTester tester) => tester.widget<VehiculoMapa>(find.byType(VehiculoMapa));

void main() {
  group('tipoVehiculoMapaDe', () {
    test('valores del registro y variantes comunes', () {
      expect(tipoVehiculoMapaDe('Motocicleta'), TipoVehiculoMapa.moto);
      expect(tipoVehiculoMapaDe('moto'), TipoVehiculoMapa.moto);
      expect(tipoVehiculoMapaDe('Sedan'), TipoVehiculoMapa.carro);
      expect(tipoVehiculoMapaDe('Sedán'), TipoVehiculoMapa.carro);
      expect(tipoVehiculoMapaDe('carro'), TipoVehiculoMapa.carro);
      expect(tipoVehiculoMapaDe('Camioneta'), TipoVehiculoMapa.camioneta);
      expect(tipoVehiculoMapaDe('Camion'), TipoVehiculoMapa.camion);
      expect(tipoVehiculoMapaDe('CAMIÓN'), TipoVehiculoMapa.camion);
      expect(tipoVehiculoMapaDe('Furgon'), TipoVehiculoMapa.furgon);
      expect(tipoVehiculoMapaDe('furgón'), TipoVehiculoMapa.furgon);
    });

    test('desconocido o vacío: camión genérico', () {
      expect(tipoVehiculoMapaDe(null), TipoVehiculoMapa.camion);
      expect(tipoVehiculoMapaDe(''), TipoVehiculoMapa.camion);
      expect(tipoVehiculoMapaDe('Tractomula'), TipoVehiculoMapa.camion);
    });
  });

  group('rumbo', () {
    test('puntos cardinales', () {
      expect(rumboEntre(_base, LatLng(_base.latitude + 0.01, _base.longitude)), closeTo(0, 0.01));
      expect(rumboEntre(_base, _alEste(100)), closeTo(90, 0.01));
      expect(rumboEntre(_base, LatLng(_base.latitude - 0.01, _base.longitude)), closeTo(180, 0.01));
      expect(rumboEntre(_base, _alEste(-100)), closeTo(270, 0.01));
    });

    test('el ruido del GPS (< 5 m) no cambia el rumbo', () {
      expect(rumboSiSeMovio(_base, _alEste(3)), isNull);
      expect(rumboSiSeMovio(_base, _alEste(8)), closeTo(90, 0.01));
      expect(rumboSiSeMovio(null, _alEste(8)), isNull);
      expect(rumboSiSeMovio(_base, _alEste(20), umbralM: 30), isNull);
    });

    test('rumbo cerca del norte da la vuelta en 0/360', () {
      final noroeste = LatLng(_base.latitude + 0.01, _base.longitude - 0.0001);
      final r = rumboEntre(_base, noroeste);
      expect(r, greaterThan(359));
      expect(r, lessThan(360));
      expect(normalizarGrados(-10), 350);
      expect(normalizarGrados(370), 10);
      expect(normalizarGrados(360), 0);
    });

    test('rumbo del payload si viene y es válido', () {
      expect(rumboDePayload({'lat': 1, 'lng': 2}), isNull);
      expect(rumboDePayload({'heading': 45}), 45);
      expect(rumboDePayload({'bearing': '370'}), 10);
      expect(rumboDePayload({'heading': -1}), isNull);
    });
  });

  group('interpolarAngulo', () {
    test('gira por el camino más corto cruzando el norte', () {
      expect(interpolarAngulo(350, 10, 0.5), closeTo(0, 1e-9));
      expect(interpolarAngulo(10, 350, 0.5), closeTo(0, 1e-9));
      expect(interpolarAngulo(350, 10, 0.25), closeTo(355, 1e-9));
    });

    test('extremos y giro normal', () {
      expect(interpolarAngulo(90, 180, 0), 90);
      expect(interpolarAngulo(90, 180, 1), 180);
      expect(interpolarAngulo(0, 90, 0.5), 45);
      expect(interpolarAngulo(270, 90, 1), 90);
    });
  });

  test('emparejarPorCercania: mismo tipo y cercano; lejos es otro vehículo', () {
    final antes = [
      (punto: _base, tipo: TipoVehiculoMapa.camion),
      (punto: _alEste(1000), tipo: TipoVehiculoMapa.moto),
    ];
    final ahora = [
      (punto: _alEste(1050), tipo: TipoVehiculoMapa.moto),
      (punto: _alEste(40), tipo: TipoVehiculoMapa.camion),
      (punto: _alEste(3000), tipo: TipoVehiculoMapa.camion),
    ];
    expect(emparejarPorCercania(antes, ahora), {0: 1, 1: 0});
  });

  test('etiqueta del vehículo asignado según la fase', () {
    expect(etiquetaVehiculoAsignado(TripStatus.aceptado), 'En camino');
    expect(etiquetaVehiculoAsignado(TripStatus.enCamino), 'En camino');
    expect(etiquetaVehiculoAsignado(TripStatus.llegada), 'En el origen');
    expect(etiquetaVehiculoAsignado(TripStatus.enCurso), 'Con tu carga');
    expect(etiquetaVehiculoAsignado(TripStatus.sos), isNull);
  });

  test('vehículos cercanos del backend: tipo y color neutro', () {
    final v = vehiculosCercanosEnMapa([
      {'lat': 2.44, 'lng': -76.61, 'tipoVehiculo': 'Motocicleta', 'distanciaKm': 0.4},
      {'lat': 2.45, 'lng': -76.62, 'tipoVehiculo': null},
      {'lng': -76.62},
    ]);
    expect(v, hasLength(2));
    expect(v[0].tipo, TipoVehiculoMapa.moto);
    expect(v[1].tipo, TipoVehiculoMapa.camion);
    expect(v.every((x) => x.color == colorVehiculoCercano && x.id == null && x.rumbo == null), isTrue);
  });

  testWidgets('el vehículo asignado se dibuja con su tipo, azul y su etiqueta', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: SizedBox(
        height: 300,
        child: MapaViaje(
          origen: LatLng(2.44, -76.6),
          destino: LatLng(2.46, -76.58),
          vehiculo: LatLng(2.45, -76.59),
          dibujarVehiculo: true,
          tipoVehiculo: 'Camioneta',
          etiquetaVehiculo: 'Con tu carga',
        ),
      ),
    ));
    await tester.pump();
    final v = _unico(tester);
    expect(v.tipo, TipoVehiculoMapa.camioneta);
    expect(v.color, colorVehiculoAsignado);
    expect(find.text('Con tu carga'), findsOneWidget);
    expect(find.byIcon(Icons.local_shipping), findsNothing);
  });

  testWidgets('se desliza y gira suavemente hacia el nuevo punto del GPS', (tester) async {
    await tester.pumpWidget(_mapa([const VehiculoEnMapa(id: 'c1', punto: _base)]));
    expect(_unico(tester).rumbo, 0);

    await tester.pumpWidget(_mapa([VehiculoEnMapa(id: 'c1', punto: _alEste(100))]));
    await tester.pump(const Duration(milliseconds: 500));
    expect(_unico(tester).rumbo, closeTo(45, 2));

    await tester.pump(const Duration(milliseconds: 600));
    expect(_unico(tester).rumbo, closeTo(90, 0.01));

    // Ruido de 2 m: no se voltea.
    await tester.pumpWidget(_mapa([VehiculoEnMapa(id: 'c1', punto: _alEste(98))]));
    await tester.pumpAndSettle();
    expect(_unico(tester).rumbo, closeTo(90, 0.01));
  });

  testWidgets('los cercanos que aparecen y desaparecen se funden', (tester) async {
    final camion = VehiculoEnMapa(punto: _alEste(50), color: colorVehiculoCercano, tamano: 40);
    await tester.pumpWidget(_mapa([camion]));
    expect(find.byType(VehiculoMapa), findsOneWidget);
    expect(find.byType(Opacity), findsNothing);

    final moto = VehiculoEnMapa(
      punto: _alEste(-200),
      tipo: TipoVehiculoMapa.moto,
      color: colorVehiculoCercano,
      tamano: 40,
    );
    await tester.pumpWidget(_mapa([moto]));
    await tester.pump(const Duration(milliseconds: 500));
    // El camión se va y la moto llega: ambos a media opacidad.
    expect(find.byType(VehiculoMapa), findsNWidgets(2));
    expect(find.byType(Opacity), findsNWidgets(2));

    await tester.pumpAndSettle();
    expect(find.byType(VehiculoMapa), findsOneWidget);
    expect(_unico(tester).tipo, TipoVehiculoMapa.moto);
  });

  testWidgets('el dibujo se pinta en todas las variantes', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Wrap(children: [
        for (final t in TipoVehiculoMapa.values)
          VehiculoMapa(tipo: t, color: colorVehiculoCercano, rumbo: 30, tamano: 44),
        const VehiculoMapa(halo: true, etiqueta: 'En camino'),
      ]),
    ));
    expect(tester.takeException(), isNull);
    expect(find.byType(VehiculoMapa), findsNWidgets(TipoVehiculoMapa.values.length + 1));
    expect(find.text('En camino'), findsOneWidget);
  });
}
