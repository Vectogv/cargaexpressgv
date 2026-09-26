import 'trip_status.dart';

/// El backend bloquea la cancelación directa (403) en `en_curso`,
/// `conductor_llegada` y `sos`: ahí el cliente envía una solicitud de
/// cancelación (la revisa un administrador) y ve los motivos de "viaje en
/// curso".
bool cancelacionRequiereSolicitud(String? estado) =>
    estado == TripStatus.enCurso || estado == TripStatus.llegada || estado == TripStatus.sos;

/// Motivo fijo que usa `BusquedaTimeoutService` al cancelar por falta de
/// conductor (`app/services/busqueda_timeout_service.ts`,
/// `MOTIVO_SIN_CONDUCTORES`). El backend no persiste `canceladoPor` en el
/// viaje: al recargar/reabrir la app solo llega `motivoCancelacion`, así que
/// esa cancelación se reconoce comparando con este texto.
const String motivoCancelacionSistema = 'Sin conductores disponibles';

/// Minutos por defecto de `BUSQUEDA_TIMEOUT_MIN` (`config/reservations.ts`).
const int busquedaTimeoutMinPorDefecto = 15;

/// True si la cancelación la hizo el sistema por falta de conductor
/// (`BusquedaTimeoutService`): lo dice `canceladoPor` en el payload en vivo
/// del socket, o el `motivoCancelacion` persistido al recargar/reabrir.
bool esCanceladoPorSistema({String? canceladoPor, String? motivo}) {
  if (canceladoPor == 'sistema') return true;
  return motivo == motivoCancelacionSistema;
}

/// Minutos de búsqueda a mostrar en el aviso de "sin conductor": el payload
/// del backend no los trae hoy (queda fijo en 15), pero se admite por si se
/// agregan más adelante.
int minutosBusquedaDesde(Map<String, dynamic> data) {
  final raw = data['busquedaTimeoutMin'] ?? data['timeoutMin'] ?? data['minutos'];
  final min = raw is num ? raw.toInt() : int.tryParse(raw?.toString() ?? '');
  return min ?? busquedaTimeoutMinPorDefecto;
}

/// Título y mensaje honestos para el aviso de "sin conductor": el cliente no
/// canceló nada, el sistema lo hizo tras `minutos` sin ofertas aceptadas.
class AvisoSinConductor {
  final String titulo;
  final String mensaje;
  const AvisoSinConductor({required this.titulo, required this.mensaje});
}

AvisoSinConductor avisoSinConductor({int minutos = busquedaTimeoutMinPorDefecto}) {
  return AvisoSinConductor(
    titulo: 'No encontramos conductor',
    mensaje: 'Pasaron $minutos minutos sin que un conductor aceptara tu envío, '
        'así que lo cancelamos. No se te cobró nada. Puedes intentarlo de nuevo.',
  );
}

/// Etiqueta de "Cancelado" para historial/detalle: el backend no persiste
/// quién canceló, así que solo se distingue el caso del sistema (el resto
/// sigue siendo un "Cancelado" genérico).
String etiquetaCancelacion(String? motivoCancelacion) =>
    esCanceladoPorSistema(motivo: motivoCancelacion)
        ? 'Cancelado: sin conductor disponible'
        : 'Cancelado';

/// Id de viaje de un payload de socket: puede venir como string directo
/// (`viajeId`) o, en payloads más viejos, como un mapa con `_id` o `id`.
String? viajeIdDesde(dynamic value) {
  if (value == null) return null;
  if (value is Map) return (value['_id'] ?? value['id'])?.toString();
  return value.toString();
}

/// Aviso para `trip:cancellation_rejected` (cliente y conductor): el admin
/// rechazó la solicitud de cancelación (`request-cancellation`) y el viaje
/// sigue activo.
String mensajeCancelacionRechazada(Map<String, dynamic> data) {
  final motivo = data['motivo']?.toString().trim();
  final sufijo = (motivo != null && motivo.isNotEmpty) ? ' Motivo: $motivo.' : '';
  return 'El administrador rechazó la cancelación. El viaje continúa.$sufijo';
}

/// Aviso para el evento de socket `trip:cancelled` según quién canceló.
///
/// El backend envía `canceladoPor` ('cliente' | 'conductor' | 'admin' |
/// 'sistema'); payloads antiguos no lo traen.
///
/// Devuelve null cuando canceló el propio usuario ([miRol]): su pantalla de
/// cancelación ya lo confirmó y un segundo aviso confunde.
String? mensajeViajeCancelado(Map<String, dynamic> data, {required String? miRol}) {
  final por = data['canceladoPor']?.toString();
  final motivoRaw = data['motivo']?.toString().trim() ?? '';
  final motivo = motivoRaw.isEmpty ? '' : ': $motivoRaw';

  if (por != null && por == miRol) return null;
  if (esCanceladoPorSistema(canceladoPor: por, motivo: motivoRaw)) {
    return avisoSinConductor(minutos: minutosBusquedaDesde(data)).mensaje;
  }
  switch (por) {
    case 'conductor':
      return 'El conductor canceló el viaje$motivo';
    case 'cliente':
      return 'El cliente canceló el viaje$motivo';
    case 'admin':
      return 'El viaje fue cancelado por soporte';
    default:
      return 'El viaje fue cancelado';
  }
}
