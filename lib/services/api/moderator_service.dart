import 'http_client.dart';

/// Endpoints del moderador de zona (`/api/moderator/*`, backend
/// `moderator_controller.ts`). Requiere `esModerador` con zona asignada (o
/// rol admin); de lo contrario el backend responde 403 con el motivo.
///
/// Es una clase con métodos de instancia (no estáticos) para poder sustituirla
/// por un doble en las pruebas de [ModeradorHomeScreen].
class ModeratorService {
  const ModeratorService();

  /// GET /api/moderator/dashboard → {ciudad, totalDrivers, inactiveDrivers,
  /// onlineDrivers, totalComunicados, totalAvisos, totalReports}
  Future<Map<String, dynamic>> getDashboard() =>
      HttpClient.get('/api/moderator/dashboard', auth: true);

  /// GET /api/moderator/trips?estado=... (viajes de la zona del moderador).
  Future<List<Map<String, dynamic>>> getTrips({String? estado, int page = 1, int limit = 50}) async {
    final query = StringBuffer('?page=$page&limit=$limit');
    if (estado != null && estado.isNotEmpty) {
      query.write('&estado=${Uri.encodeQueryComponent(estado)}');
    }
    final list = await HttpClient.getList('/api/moderator/trips$query', auth: true);
    return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// Viajes cuyo cierre espera la confirmación del cliente.
  Future<List<Map<String, dynamic>>> getPendingCloses() =>
      getTrips(estado: 'pendiente_confirmacion');

  /// POST /api/moderator/trips/:id/resolve-close
  /// `resolucion`: `finalizar` | `disputa`; `nota`: mínimo 10 caracteres.
  /// Errores posibles del backend (se muestran tal cual): 409
  /// CONFIRMACION_EN_PLAZO si el cliente aún está dentro del plazo, 422 si el
  /// viaje ya no está pendiente o la nota es corta, 403 si es de otra ciudad.
  Future<Map<String, dynamic>> resolvePendingClose(
    dynamic tripId, {
    required String resolucion,
    required String nota,
  }) =>
      HttpClient.post(
        '/api/moderator/trips/$tripId/resolve-close',
        body: {'resolucion': resolucion, 'nota': nota},
        auth: true,
      );

  /// GET /api/moderator/emergency (alertas SOS de la zona).
  Future<List<Map<String, dynamic>>> getEmergencies({String? estado}) async {
    final q = (estado != null && estado.isNotEmpty)
        ? '?estado=${Uri.encodeQueryComponent(estado)}'
        : '';
    final list = await HttpClient.getList('/api/moderator/emergency$q', auth: true);
    return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// POST /api/moderator/emergency/:id/acknowledge
  Future<Map<String, dynamic>> acknowledgeEmergency(dynamic id) =>
      HttpClient.post('/api/moderator/emergency/$id/acknowledge', auth: true);

  /// POST /api/moderator/emergency/:id/resolve {observacion?}
  Future<Map<String, dynamic>> resolveEmergency(dynamic id, {String? observacion}) =>
      HttpClient.post(
        '/api/moderator/emergency/$id/resolve',
        body: {
          if (observacion != null && observacion.trim().isNotEmpty)
            'observacion': observacion.trim(),
        },
        auth: true,
      );
}
