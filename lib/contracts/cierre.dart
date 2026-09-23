import 'dart:math';

/// Distancia en km entre dos coordenadas (haversine, como `distanciaKm` del
/// backend).
double distanciaKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  double rad(double g) => g * pi / 180.0;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(rad(lat1)) * cos(rad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
  return r * 2 * asin(sqrt(a));
}

/// El backend (`trip_controller.ts` complete) exige una justificación de al
/// menos 10 caracteres sólo si el conductor está a `radioCierreKm` o más del
/// destino. Sin ubicación o sin destino conocidos se pide (lado seguro); el
/// backend sigue siendo quien decide.
bool cierreRequiereJustificacion({
  required double? lat,
  required double? lng,
  required double? destinoLat,
  required double? destinoLng,
  required double radioKm,
}) {
  if (lat == null || lng == null || destinoLat == null || destinoLng == null) return true;
  return distanciaKm(lat, lng, destinoLat, destinoLng) >= radioKm;
}
