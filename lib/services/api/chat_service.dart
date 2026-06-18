import 'http_client.dart';

class ChatService {
  static Future<List<Map<String, dynamic>>> getTripMessages(dynamic tripId) async {
    final list = await HttpClient.getList('/api/trips/$tripId/chat', auth: true);
    return list.cast<Map<String, dynamic>>();
  }

  static Future<void> sendTripMessage(dynamic tripId, String text) async {
    await HttpClient.post('/api/trips/$tripId/chat', body: {'mensaje': text}, auth: true);
  }
}
