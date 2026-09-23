import 'package:flutter_test/flutter_test.dart';

import 'package:cargaexpress/contracts/cierre.dart';

void main() {
  const dLat = 4.6097, dLng = -74.0817; // destino

  test('dentro del radio no pide justificación', () {
    expect(
      cierreRequiereJustificacion(lat: 4.6100, lng: -74.0820, destinoLat: dLat, destinoLng: dLng, radioKm: 1),
      isFalse,
    );
  });

  test('fuera del radio sí la pide (el backend usa >= radio)', () {
    // ~2,2 km al norte.
    expect(
      cierreRequiereJustificacion(lat: 4.6297, lng: -74.0817, destinoLat: dLat, destinoLng: dLng, radioKm: 1),
      isTrue,
    );
  });

  test('sin ubicación o sin destino se pide (lado seguro)', () {
    expect(cierreRequiereJustificacion(lat: null, lng: null, destinoLat: dLat, destinoLng: dLng, radioKm: 1), isTrue);
    expect(cierreRequiereJustificacion(lat: 4.61, lng: -74.08, destinoLat: null, destinoLng: null, radioKm: 1), isTrue);
  });

  test('distanciaKm aproxima la del backend (haversine)', () {
    expect(distanciaKm(4.6097, -74.0817, 4.6297, -74.0817), closeTo(2.22, 0.02));
  });
}
