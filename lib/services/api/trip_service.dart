import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../api_client.dart';
import 'http_client.dart';

class TripService {
  static Future<Map<String, dynamic>> requestTrip(Map<String, dynamic> data) async {
    return HttpClient.post('/api/trips/request', body: data, auth: true);
  }

  static Future<Map<String, dynamic>?> getActiveTrip() async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (ApiClient.instance.token != null) {
      headers['Authorization'] = 'Bearer ${ApiClient.instance.token}';
    }
    final res = await http.get(
      Uri.parse('${HttpClient.baseUrl}/api/trips/active'),
      headers: headers,
    );
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) {
      throw Exception(_extractError(jsonDecode(res.body)));
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<List<Map<String, dynamic>>> getTripHistory({int page = 1, int limit = 20, String? estado}) async {
    String url = '/api/trips/history?page=$page&limit=$limit';
    if (estado != null && estado.isNotEmpty) url += '&estado=$estado';
    final data = await HttpClient.get(url, auth: true);
    return (data['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  }

  static Future<Map<String, dynamic>> getTripDetail(dynamic id) async {
    return HttpClient.get('/api/trips/$id', auth: true);
  }

  static Future<List<Map<String, dynamic>>> getNearbyTrips(double lat, double lng, {double radio = 5}) async {
    final list = await HttpClient.getList('/api/trips/nearby?lat=$lat&lng=$lng&radio=$radio', auth: true);
    return list.cast<Map<String, dynamic>>();
  }

  static Future<void> startTrip(dynamic id) async {
    await HttpClient.post('/api/trips/$id/start-trip', auth: true);
  }

  static Future<void> completeTrip(dynamic id, {num? montoFinal}) async {
    final body = <String, dynamic>{};
    if (montoFinal != null) body['montoFinal'] = montoFinal;
    await HttpClient.post('/api/trips/$id/complete', body: body, auth: true);
  }

  static Future<void> finalizeTrip(dynamic id, {num? montoFinal}) async {
    final body = <String, dynamic>{};
    if (montoFinal != null) body['montoFinal'] = montoFinal;
    await HttpClient.post('/api/trips/$id/finalize', body: body, auth: true);
  }

  static Future<void> confirmArrival(dynamic id) async {
    await HttpClient.post('/api/trips/$id/confirm-arrival', auth: true);
  }

  static Future<void> confirmPickup(dynamic id) async {
    await HttpClient.post('/api/trips/$id/confirm-pickup', auth: true);
  }

  static Future<void> cancelTrip(dynamic id, {String? motivo}) async {
    await HttpClient.post('/api/trips/$id/cancel', body: {'motivo': motivo}, auth: true);
  }

  static Future<void> requestCancellation(dynamic id, {String? motivo}) async {
    await HttpClient.post('/api/trips/$id/request-cancellation', body: {'motivo': motivo}, auth: true);
  }

  static Future<Map<String, dynamic>> disputeTrip(dynamic id, {required String motivo, String? descripcion}) async {
    return HttpClient.post('/api/trips/$id/dispute', body: {'motivo': motivo, 'descripcion': descripcion}, auth: true);
  }

  static Future<void> rateTrip(dynamic id, int puntaje, {String? comentario}) async {
    await HttpClient.post('/api/trips/$id/rate', body: {'puntaje': puntaje, 'comentario': comentario}, auth: true);
  }

  static Future<String> deliveryPhoto(dynamic tripId, Uint8List bytes, String filename) async {
    final data = await HttpClient.uploadFile('/api/trips/$tripId/delivery-photo', bytes: bytes, filename: filename, fieldName: 'file', auth: true);
    return data['url'] as String? ?? '';
  }

  static Future<String> disputePhoto(dynamic tripId, Uint8List bytes, String filename) async {
    final data = await HttpClient.uploadFile('/api/trips/$tripId/dispute-photo', bytes: bytes, filename: filename, fieldName: 'foto', auth: true);
    return data['url'] as String? ?? '';
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
