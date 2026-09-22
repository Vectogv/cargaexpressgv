import '../../services/api/http_client.dart';

/// Clave de idempotencia para UNA acción del usuario (solicitar viaje,
/// cerrar servicio, confirmar cierre...).
///
/// - Se genera cuando el usuario toca el botón y se reutiliza si reintenta
///   tras un fallo de red / timeout / 5xx: el backend no duplica la operación.
/// - Si el backend respondió (2xx o 4xx) la clave se descarta: el middleware
///   cachea esas respuestas 60 s, y reutilizarla repetiría el mismo error
///   aunque el usuario ya lo haya corregido.
/// - Si cambia el cuerpo de la petición se genera una clave nueva.
class ActionKey {
  String? _key;
  String? _signature;

  String keyFor([Object? body]) {
    final sig = body?.toString();
    if (_key == null || sig != _signature) {
      _key = HttpClient.newIdempotencyKey();
      _signature = sig;
    }
    return _key!;
  }

  /// Llamar tras cada intento con el error (o null si salió bien).
  void settle([Object? error]) {
    if (error == null) {
      _key = null;
      return;
    }
    final status = error is ApiException ? error.statusCode : null;
    if (status != null && status < 500) _key = null;
  }
}
