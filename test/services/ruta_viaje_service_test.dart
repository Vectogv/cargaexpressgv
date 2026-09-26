import 'package:flutter_test/flutter_test.dart';

import 'package:cargaexpress/contracts/trip_status.dart';
import 'package:cargaexpress/screens/cliente/rastreo_screen.dart';
import 'package:cargaexpress/services/ruta_viaje_service.dart';

/// Ruta y ETA del backend (GET /trips/:id/route, trip:route_update,
/// trip:eta_update): la misma para cliente y conductor.
void main() {
  test('lee la ruta del backend con sus puntos [lat, lng]', () {
    final r = RutaViaje.fromJson({
      'tripId': '31',
      'fase': 'destino',
      'minutos': 18,
      'restanteM': 6635,
      'aproximada': false,
      'coords': [
        [2.4728, -76.5706],
        [2.4725, -76.5708],
        [2.4723, -76.5712],
      ],
    })!;
    expect(r.fase, 'destino');
    expect(r.minutos, 18);
    expect(r.restanteM, 6635);
    expect(r.coords, hasLength(3));
    expect(r.coords!.first.latitude, 2.4728);
    expect(r.coords!.first.longitude, -76.5706);
    expect(r.minutosTexto, '18 min');
  });

  test('trip:eta_update no trae línea y una fase desconocida se ignora', () {
    final eta = RutaViaje.fromJson({'fase': 'recogida', 'minutos': 4.2})!;
    expect(eta.coords, isNull);
    expect(eta.minutos, 5);
    expect(RutaViaje.fromJson({'minutos': 4}), isNull);
    expect(RutaViaje.fromJson({'fase': 'x', 'minutos': 4}), isNull);
  });

  test('trae la posición del conductor y cuándo la mandó (respaldo sin socket)', () {
    final r = RutaViaje.fromJson({
      'fase': 'recogida',
      'minutos': 2,
      'restanteM': 400,
      'conductor': {'lat': 2.4419, 'lng': -76.6063},
      'ubicacionActualizadaEn': '2026-09-25T10:00:00.000Z',
    })!;
    expect(r.conductor?.latitude, 2.4419);
    expect(r.conductor?.longitude, -76.6063);
    expect(r.ubicacionActualizadaEn, DateTime.utc(2026, 9, 25, 10));

    // Backend anterior (sin posición) o posición vacía: no se inventa nada.
    expect(RutaViaje.fromJson({'fase': 'recogida', 'minutos': 2})!.conductor, isNull);
    final vacia = RutaViaje.fromJson({'fase': 'recogida', 'conductor': {'lat': 0, 'lng': 0}, 'ubicacionActualizadaEn': null})!;
    expect(vacia.conductor, isNull);
    expect(vacia.ubicacionActualizadaEn, isNull);
  });

  test('horas en el texto del ETA', () {
    expect(const RutaViaje(fase: 'destino', minutos: 75).minutosTexto, '1 h 15 min');
    expect(const RutaViaje(fase: 'destino').minutosTexto, isNull);
  });

  test('el cliente ve el ETA al destino desde que el conductor está en el origen', () {
    expect(etaDestino(status: TripStatus.enCurso, minutosServidor: 18), '18 min');
    expect(etaDestino(status: TripStatus.llegada, minutosServidor: 0), '1 min');
    expect(etaDestino(status: TripStatus.enCurso, minutosServidor: 90), '1 h 30 min');
    expect(etaDestino(status: TripStatus.enCurso), isNull);
    expect(etaDestino(status: TripStatus.aceptado, minutosServidor: 5), isNull);
  });
}
