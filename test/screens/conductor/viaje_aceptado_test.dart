import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:cargaexpress/screens/conductor/oferta_aceptada_screen.dart';
import 'package:cargaexpress/screens/conductor/trip_in_progress_screen.dart';
import 'package:cargaexpress/widgets/mapa_viaje.dart';

import '../../helpers/fake_api.dart';

/// "Viaje aceptado" del conductor: el mapa muestra la recogida (con la ruta
/// del backend si existe) y el botón hace la transición real de esta fase
/// (confirm-arrival → conductor_en_camino).
void main() {
  late bool rutaDisponible;
  late bool rechazarLlegada;

  http.Response backend(http.Request req) {
    final p = req.url.path;
    if (p == '/api/trips/9/route') {
      if (!rutaDisponible) return errorResp(404, 'Sin ruta', 'SIN_RUTA');
      return jsonResp({
        'fase': 'recogida',
        'minutos': 6,
        'restanteM': 2400,
        'coords': [
          [4.62, -74.02],
          [4.61, -74.01],
          [4.6, -74.0],
        ],
      });
    }
    if (p == '/api/trips/9/confirm-arrival') {
      if (rechazarLlegada) return errorResp(409, 'El viaje ya no está en estado aceptado.', 'ESTADO_INVALIDO');
      return jsonResp({'id': '9', 'estado': 'conductor_en_camino'});
    }
    if (p == '/api/config/cliente') return jsonResp({'radioCierreKm': 1, 'confirmacionTimeoutMin': 15});
    return jsonResp({});
  }

  Map<String, dynamic> viaje() => {
        'id': '9',
        'estado': 'aceptado',
        'origen': {'direccion': 'Calle 10 #5-20', 'lat': 4.6, 'lng': -74.0},
        'destino': {'direccion': 'Carrera 7 #80-15', 'lat': 4.7, 'lng': -74.1},
        'cliente': {'id': 2, 'nombre': 'Ana', 'telefono': '3001110001'},
        'precioFinal': 60000,
      };

  setUp(() {
    rutaDisponible = true;
    rechazarLlegada = false;
  });

  Future<void> abrir(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 3200);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: OfertaAceptadaScreen.desdeViaje(viaje(), montoOferta: '\$60.000')));
    await avanzar(tester, 1);
  }

  Future<void> cerrar(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 2));
  }

  testWidgets('el mapa marca la recogida (no el destino) y dibuja la ruta del backend hacia ella', (tester) async {
    await conApiFalsa(backend, () async {
      await abrir(tester);
      expect(find.text('Viaje aceptado'), findsOneWidget);
      expect(find.text('¡Oferta aceptada!'), findsOneWidget);
      expect(find.text('Ana'), findsOneWidget);
      expect(find.text('Calle 10 #5-20'), findsOneWidget);
      expect(find.text('Carrera 7 #80-15'), findsOneWidget);
      expect(find.text('\$60.000'), findsOneWidget);

      final mapa = tester.widget<MapaViaje>(find.byKey(const Key('mapa_recogida')));
      expect(mapa.origen, isNotNull);
      expect(mapa.destino, isNull);
      expect(mapa.ruta, isNotNull);
      expect(mapa.ruta!.length, 3);
      expect(mapa.rutaAproximada, isFalse);

      // La etiqueta describe la acción real de esta fase.
      expect(find.text('Voy en camino a recoger'), findsOneWidget);
      expect(find.text('Iniciar viaje'), findsNothing);
      await cerrar(tester);
    });
  });

  testWidgets('sin ruta todavía el mapa sólo marca la recogida', (tester) async {
    rutaDisponible = false;
    await conApiFalsa(backend, () async {
      await abrir(tester);
      final mapa = tester.widget<MapaViaje>(find.byKey(const Key('mapa_recogida')));
      expect(mapa.origen, isNotNull);
      expect(mapa.destino, isNull);
      expect(mapa.ruta, isNull);
      await cerrar(tester);
    });
  });

  testWidgets('"Voy en camino a recoger" llama a confirm-arrival y abre el viaje ya en camino', (tester) async {
    final log = <http.Request>[];
    await conApiFalsa(backend, () async {
      await abrir(tester);
      await tester.tap(find.byKey(const Key('btn_voy_en_camino')));
      await avanzar(tester, 2);

      expect(log.where((r) => r.method == 'POST' && r.url.path == '/api/trips/9/confirm-arrival'), hasLength(1));
      expect(find.byType(OfertaAceptadaScreen), findsNothing);
      expect(find.byType(TripInProgressScreen), findsOneWidget);
      expect(find.text('En camino al origen'), findsOneWidget);
      expect(find.text('Llegué al origen'), findsOneWidget);
      await cerrar(tester);
    }, log: log);
  });

  testWidgets('si el backend rechaza la transición se muestra el motivo y se abre el viaje en su estado real', (tester) async {
    rechazarLlegada = true;
    await conApiFalsa(backend, () async {
      await abrir(tester);
      await tester.tap(find.byKey(const Key('btn_voy_en_camino')));
      await avanzar(tester, 2);

      expect(find.byType(TripInProgressScreen), findsOneWidget);
      expect(find.text('El viaje ya no está en estado aceptado.'), findsOneWidget);
      // La vista del viaje conserva su propio botón para la fase aceptado.
      expect(find.text('Voy en camino al origen'), findsOneWidget);
      await cerrar(tester);
    });
  });
}
