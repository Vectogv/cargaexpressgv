import 'dart:typed_data';

import 'http_client.dart';

class DriverService {
  static Future<void> setDriverStatus(bool online) async {
    await HttpClient.put('/api/drivers/status', body: {'online': online}, auth: true);
  }

  static Future<void> updateLocation(double lat, double lng) async {
    // Usa HttpClient (refresca token ante 401) y tolera el 429 del rate-limit
    // del endpoint GPS para no cortar el timbre de ubicación en segundo plano.
    try {
      await HttpClient.put('/api/drivers/location', body: {'lat': lat, 'lng': lng}, auth: true);
    } on ApiException catch (e) {
      if (e.statusCode == 429) return;
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getEarnings() async {
    return HttpClient.get('/api/drivers/earnings', auth: true);
  }

  static Future<Map<String, dynamic>> getDriverStats() async {
    return HttpClient.get('/api/drivers/stats', auth: true);
  }

  static Future<Map<String, dynamic>> getTodayStats() async {
    return HttpClient.get('/api/drivers/today-stats', auth: true);
  }

  static Future<Map<String, dynamic>> getDebt() async {
    return HttpClient.get('/api/payment/debt', auth: true);
  }

  static Future<Map<String, dynamic>> getEarningsHistory({String periodo = 'todo', int page = 1, int limit = 20}) async {
    return HttpClient.get('/api/drivers/earnings/history?periodo=$periodo&page=$page&limit=$limit', auth: true);
  }

  static Future<List<int>> getEarningsPdf({String periodo = 'todo'}) async {
    return HttpClient.getBytes('/api/drivers/earnings/pdf?periodo=$periodo', auth: true);
  }

  static Future<String> uploadDocumentCedula(Uint8List bytes, String filename) async {
    final data = await HttpClient.uploadFile('/api/drivers/verification/cedula', bytes: bytes, filename: filename, fieldName: 'file', auth: true);
    return data['fotoCedula'] as String? ?? '';
  }

  static Future<String> uploadDocumentLicencia(Uint8List bytes, String filename) async {
    final data = await HttpClient.uploadFile('/api/drivers/verification/licencia', bytes: bytes, filename: filename, fieldName: 'file', auth: true);
    return data['fotoLicencia'] as String? ?? '';
  }

  static Future<String> uploadDocumentVehiculo(Uint8List bytes, String filename) async {
    final data = await HttpClient.uploadFile('/api/drivers/verification/vehiculo', bytes: bytes, filename: filename, fieldName: 'file', auth: true);
    return data['fotoVehiculo'] as String? ?? '';
  }

  /// Documentos nuevos: `cedula-reverso`, `tarjeta-propiedad`, `tecnomecanica`
  /// y `soat` (los 2 últimos con [vence] `YYYY-MM-DD`; el servidor rechaza
  /// fechas vencidas con 422).
  static Future<Map<String, dynamic>> uploadDocumento(String tipo, Uint8List bytes, String filename, {String? vence}) {
    return HttpClient.uploadFile(
      '/api/drivers/verification/$tipo',
      bytes: bytes,
      filename: filename,
      fieldName: 'file',
      auth: true,
      fields: vence == null ? null : {'vence': vence},
    );
  }

  /// "¿No tienes SOAT?": pide que CargaExpress valore el vehículo. Queda `pendiente`.
  static Future<Map<String, dynamic>> solicitarExcepcionSoat(String comentario) {
    return HttpClient.post('/api/drivers/verification-soat/excepcion', body: {'comentario': comentario}, auth: true);
  }

  static Future<String> uploadDocumentDriverPhoto(Uint8List bytes, String filename) async {
    final data = await HttpClient.uploadFile('/api/drivers/driver-photo', bytes: bytes, filename: filename, fieldName: 'file', auth: true);
    return data['fotoConductor'] as String? ?? '';
  }

  static Future<String> uploadPaymentProof(Uint8List bytes, String filename) async {
    final data = await HttpClient.uploadFile(
      '/api/payment/proof', 
      bytes: bytes, 
      filename: filename, 
      fieldName: 'file', 
      auth: true
    );
    return data['comprobante'] as String? ?? data['url'] as String? ?? '';
  }
}
