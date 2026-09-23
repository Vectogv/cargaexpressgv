import 'trip_status.dart';

/// El backend bloquea la cancelación directa (403) en `en_curso` y
/// `conductor_llegada`: ahí el cliente envía una solicitud de cancelación y
/// ve los motivos de "viaje en curso".
bool cancelacionRequiereSolicitud(String? estado) =>
    estado == TripStatus.enCurso || estado == TripStatus.llegada;

/// Aviso para el evento de socket `trip:cancelled` según quién canceló.
///
/// El backend envía `canceladoPor` ('cliente' | 'conductor' | 'admin');
/// payloads antiguos no lo traen.
///
/// Devuelve null cuando canceló el propio usuario ([miRol]): su pantalla de
/// cancelación ya lo confirmó y un segundo aviso confunde.
String? mensajeViajeCancelado(Map<String, dynamic> data, {required String? miRol}) {
  final por = data['canceladoPor']?.toString();
  final motivoRaw = data['motivo']?.toString().trim() ?? '';
  final motivo = motivoRaw.isEmpty ? '' : ': $motivoRaw';

  if (por != null && por == miRol) return null;
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
