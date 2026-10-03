import 'dart:typed_data';
import 'coverage_service.dart';
import 'http_client.dart';

class ProfileService {
  static Future<Map<String, dynamic>> getProfile() async {
    return HttpClient.get('/api/users/profile', auth: true);
  }

  static Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    return HttpClient.put('/api/users/profile', body: data, auth: true);
  }

  static Future<String> uploadAvatar(Uint8List bytes, String filename) async {
    final data = await HttpClient.uploadFile('/api/users/avatar', bytes: bytes, filename: filename, fieldName: 'file', auth: true);
    return data['avatar'] as String? ?? '';
  }

  /// El admin resetea la contraseña por soporte; este es el único cambio que
  /// puede hacer el propio usuario. 422 con `{message}` si la actual no
  /// coincide (ver `_DialogoCambiarPassword` en shared/cambiar_password.dart).
  static Future<void> changePassword(String actual, String nueva) async {
    await HttpClient.put('/api/users/password', body: {'actual': actual, 'nueva': nueva}, auth: true);
  }

  /// "Eliminar mi cuenta" (lo exige Play). El servidor archiva la cuenta, sin
  /// borrar datos, y responde 409 con `message` si hay un viaje activo, deuda
  /// o disputa (eso lo revisa soporte).
  static Future<void> eliminarCuenta() async {
    await HttpClient.delete('/api/users/me', auth: true);
  }

  static Future<List<Map<String, dynamic>>> getNotifications({
    int page = 1,
    int limit = 20,
  }) async {
    final list = await HttpClient.getList('/api/notifications?page=$page&limit=$limit', auth: true);
    return list.cast<Map<String, dynamic>>();
  }

  static Future<void> markNotificationRead(dynamic id) async {
    await HttpClient.put('/api/notifications/$id/read', auth: true);
  }

  /// Marca todas las del usuario en una sola llamada (responde `{actualizadas: N}`).
  static Future<void> markAllNotificationsRead() async {
    await HttpClient.put('/api/notifications/read-all', auth: true);
  }

  static Future<Map<String, dynamic>> getSettings() async {
    return HttpClient.get('/api/settings', auth: true);
  }

  static Future<Map<String, dynamic>> updateSettings(Map<String, dynamic> data) async {
    return HttpClient.put('/api/settings', body: data, auth: true);
  }

  /// Contacto y preguntas frecuentes de soporte. Endpoint público en el
  /// backend (no exige sesión): así la pantalla de Soporte muestra teléfono y
  /// correo también sin iniciar sesión (p. ej. con la cuenta suspendida).
  static Future<Map<String, dynamic>> getHelp() async {
    return HttpClient.get('/api/support/help', auth: false);
  }

  static Future<Map<String, dynamic>> getEmergencyNumbers() async {
    return HttpClient.get('/api/support/emergency', auth: true);
  }

  /// Zonas de cobertura (ver [CoverageService] e [isInsideCoverage]).
  static Future<List<Map<String, dynamic>>> getCoverage() => CoverageService.getCoverage();

  static Future<String> fetchMapboxToken() async {
    final data = await HttpClient.get('/api/config/mapbox', auth: true);
    return data['mapboxAccessToken'] as String;
  }
}
