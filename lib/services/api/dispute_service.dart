import 'http_client.dart';

class DisputeService {
  static Future<Map<String, dynamic>> createDispute({
    required dynamic tripId,
    required String problema,
    String? descripcion,
    List<String>? fotos,
  }) async {
    return HttpClient.post('/api/disputes', body: {
      'tripId': tripId,
      'problema': problema,
      'descripcion': descripcion,
      'fotos': fotos ?? [],
    }, auth: true);
  }

  static Future<Map<String, dynamic>> getDispute(dynamic id) async {
    return HttpClient.get('/api/disputes/$id', auth: true);
  }

  static Future<Map<String, dynamic>> submitVersion(dynamic id, String version) async {
    return HttpClient.post('/api/disputes/$id/version', body: {'version': version}, auth: true);
  }
}
