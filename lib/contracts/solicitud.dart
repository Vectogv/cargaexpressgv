// Reglas de una solicitud de servicio vista por el conductor (viaje que el
// backend tiene buscando conductor). Fuente: `offer_controller.ts`,
// `busqueda_timeout_service.ts` y `geo_service.obtenerViajesCercanos`.

/// La solicitud admite ofertas sólo mientras el backend busca conductor
/// (`buscando_conductor` o `pendiente` con ofertas sin aceptar).
bool solicitudSigueAbierta(dynamic estado) {
  final e = estado?.toString();
  return e == null || e == 'buscando_conductor' || e == 'pendiente';
}

/// Minutos que el backend deja buscar conductor (BUSQUEDA_TIMEOUT_MIN,
/// BusquedaTimeoutService): la solicitud sigue abierta a ofertas hasta
/// entonces, salvo que otro conductor la gane o el cliente cancele (eso lo
/// avisan los sockets). Antes la app la cerraba a los 28 s por su cuenta.
const int busquedaTimeoutMin = 15;

/// Segundos que le quedan a la solicitud según el backend: `expiresIn` si
/// viene; si no, desde `createdAt`/`created_at` + [busquedaTimeoutMin].
int segundosRestantesSolicitud(Map<String, dynamic> trip, DateTime ahora) {
  const total = busquedaTimeoutMin * 60;
  final expiresIn = trip['expiresIn'];
  if (expiresIn is num) return expiresIn.toInt().clamp(0, total);
  final raw = (trip['createdAt'] ?? trip['created_at'])?.toString();
  final creado = raw == null ? null : DateTime.tryParse(raw);
  if (creado == null) return total;
  return (total - ahora.difference(creado).inSeconds).clamp(0, total);
}

/// Identificador del viaje en cualquiera de los formatos del backend
/// (`_id`/`id` en GET /nearby y detalle, `tripId`/`viajeId` en sockets).
String? idDeViaje(Map<String, dynamic> datos) {
  final id = datos['_id'] ?? datos['id'] ?? datos['tripId'] ?? datos['viajeId'];
  final s = id?.toString();
  return (s == null || s.isEmpty) ? null : s;
}
