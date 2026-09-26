import 'package:latlong2/latlong.dart';

import 'api/http_client.dart';

/// Ruta y ETA de un viaje calculados por el backend (trip_route_service):
/// cliente y conductor dibujan la misma línea y ven los mismos minutos, y las
/// apps ya no piden la ruta a Mapbox por su cuenta.
class RutaViaje {
  /// 'recogida' (conductor → origen) o 'destino' (→ destino).
  final String fase;
  final int? minutos;
  final double? restanteM;
  final bool aproximada;

  /// Puntos de la ruta; null en `trip:eta_update` (sólo trae el ETA).
  final List<LatLng>? coords;

  /// Posición del conductor con la que el backend calculó la ruta (la última
  /// que recibió por PUT /drivers/location). Sirve de respaldo cuando
  /// `driver:location` no llega (socket cortado en segundo plano).
  final LatLng? conductor;

  /// Cuándo mandó el conductor esa posición (reloj del servidor); null si el
  /// backend no lo informa.
  final DateTime? ubicacionActualizadaEn;

  const RutaViaje({
    required this.fase,
    this.minutos,
    this.restanteM,
    this.aproximada = false,
    this.coords,
    this.conductor,
    this.ubicacionActualizadaEn,
  });

  /// Payload de GET /trips/:id/route, `trip:route_update` o `trip:eta_update`.
  /// null si no trae una fase conocida.
  static RutaViaje? fromJson(Map<String, dynamic> json) {
    final fase = json['fase']?.toString();
    if (fase != 'recogida' && fase != 'destino') return null;
    final min = json['minutos'];
    final restante = json['restanteM'];
    List<LatLng>? coords;
    final crudo = json['coords'];
    if (crudo is List) {
      coords = [
        for (final p in crudo)
          if (p is List && p.length >= 2 && p[0] is num && p[1] is num)
            LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()),
      ];
    }
    LatLng? conductor;
    final pos = json['conductor'];
    if (pos is Map) {
      final lat = pos['lat'] ?? pos['latitude'];
      final lng = pos['lng'] ?? pos['longitude'];
      if (lat is num && lng is num && !(lat == 0 && lng == 0)) {
        conductor = LatLng(lat.toDouble(), lng.toDouble());
      }
    }
    final actualizada = json['ubicacionActualizadaEn'];
    return RutaViaje(
      fase: fase!,
      minutos: min is num ? min.ceil() : int.tryParse(min?.toString() ?? ''),
      restanteM: restante is num ? restante.toDouble() : null,
      aproximada: json['aproximada'] == true,
      coords: coords,
      conductor: conductor,
      ubicacionActualizadaEn: actualizada is String ? DateTime.tryParse(actualizada)?.toUtc() : null,
    );
  }

  /// "8 min", "1 h 5 min" o null sin dato.
  String? get minutosTexto {
    final m = minutos;
    if (m == null) return null;
    if (m >= 60) return '${m ~/ 60} h ${m % 60} min';
    return '${m < 1 ? 1 : m} min';
  }

  static Future<RutaViaje?> obtener(dynamic tripId) async {
    try {
      final data = await HttpClient.get('/api/trips/$tripId/route', auth: true);
      return fromJson(data);
    } catch (_) {
      // 404 SIN_UBICACION / SIN_RUTA o sin red: la pantalla sigue sin ruta
      // hasta el próximo trip:route_update.
      return null;
    }
  }
}
