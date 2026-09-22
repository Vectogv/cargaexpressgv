import 'dart:math' as math;

import 'http_client.dart';

/// Zonas de cobertura de la plataforma (GET /api/config/coverage, público).
///
/// Respuesta: `{ zonas: [{clave, nombre, norte, sur, este, oeste}] }`
/// (rectángulos); zonas antiguas pueden venir como círculo
/// `{clave, nombre, lat, lng, radio}` (radio en km).
class CoverageService {
  CoverageService._();

  /// Lista de zonas activas. Lanza [ApiException] ante error de red/servidor.
  static Future<List<Map<String, dynamic>>> getCoverage() async {
    final data = await HttpClient.get('/api/config/coverage');
    final zonas = data['zonas'];
    if (zonas is! List) return <Map<String, dynamic>>[];
    return zonas
        .whereType<Map>()
        .map((z) => Map<String, dynamic>.from(z))
        .toList();
  }
}

double? _num(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return 2 * r * math.asin(math.min(1.0, math.sqrt(a)));
}

/// `true` si el punto cae dentro de alguna zona. Soporta rectángulos
/// (`norte/sur/este/oeste`) y círculos antiguos (`lat/lng/radio` km, o
/// `centro: {lat, lng}` + `radio`). Sin zonas se considera cubierto (el
/// backend es la validación definitiva). Función pura.
bool isInsideCoverage(List zonas, double lat, double lng) {
  if (!lat.isFinite || !lng.isFinite) return false;
  final validas = zonas.whereType<Map>().toList();
  if (validas.isEmpty) return true;
  for (final z in validas) {
    final norte = _num(z['norte']);
    final sur = _num(z['sur']);
    final este = _num(z['este']);
    final oeste = _num(z['oeste']);
    if (norte != null && sur != null && este != null && oeste != null) {
      if (lat <= norte && lat >= sur && lng <= este && lng >= oeste) return true;
      continue;
    }
    final centro = z['centro'];
    final cLat = _num(z['lat']) ?? (centro is Map ? _num(centro['lat']) : null);
    final cLng = _num(z['lng']) ?? (centro is Map ? _num(centro['lng']) : null);
    final radio = _num(z['radio']);
    if (cLat != null && cLng != null && radio != null && radio > 0) {
      if (_haversineKm(lat, lng, cLat, cLng) <= radio) return true;
    }
  }
  return false;
}
