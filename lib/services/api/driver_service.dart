import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../api_client.dart';
import 'http_client.dart';

class DriverService {
  static Future<void> setDriverStatus(bool online) async {
    await HttpClient.put('/api/drivers/status', body: {'online': online}, auth: true);
  }

  static Future<void> updateLocation(double lat, double lng) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (ApiClient.instance.token != null) {
      headers['Authorization'] = 'Bearer ${ApiClient.instance.token}';
    }
    final res = await http.put(
      Uri.parse('${HttpClient.baseUrl}/api/drivers/location'),
      headers: headers,
      body: jsonEncode({'lat': lat, 'lng': lng}),
    );
    if (res.statusCode == 429) return;
    if (res.statusCode != 200) {
      throw Exception(_extractError(jsonDecode(res.body)));
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

  static String _extractError(dynamic data) {
    if (data is Map) {
      if (data['message'] != null) return data['message'] as String;
      final errors = data['errors'];
      if (errors is List && errors.isNotEmpty) {
        return (errors[0] as Map<String, dynamic>)['message'] as String? ?? 'Error desconocido';
      }
      if (data['error'] != null) return data['error'] as String;
    }
    return 'Error desconocido';
  }
}
