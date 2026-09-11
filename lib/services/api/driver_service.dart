import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../api_client.dart';
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
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (ApiClient.instance.token != null) {
      headers['Authorization'] = 'Bearer ${ApiClient.instance.token}';
    }
    final res = await http.get(
      Uri.parse('${HttpClient.baseUrl}/api/drivers/earnings/pdf?periodo=$periodo'),
      headers: headers,
    );
    if (res.statusCode != 200) throw Exception('Error al descargar PDF');
    return res.bodyBytes.toList();
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
