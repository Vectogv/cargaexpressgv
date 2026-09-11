import 'http_client.dart';

class ChatService {
  static Future<List<Map<String, dynamic>>> getTripMessages(dynamic tripId) async {
    final list = await HttpClient.getList('/api/trips/$tripId/chat', auth: true);
    return list.cast<Map<String, dynamic>>();
  }

  static Future<void> sendTripMessage(dynamic tripId, String text) async {
    await HttpClient.post('/api/trips/$tripId/chat', body: {'mensaje': text}, auth: true);
  }

  static Future<List<Map<String, dynamic>>> getConversations() async {
    final list = await HttpClient.getList('/api/conversations', auth: true);
    return list.cast<Map<String, dynamic>>();
  }

  static Future<List<Map<String, dynamic>>> getConversationMessages(dynamic conversationId) async {
    final list = await HttpClient.getList('/api/conversations/$conversationId/messages', auth: true);
    return list.cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> sendConversationMessage(dynamic conversationId, String text) async {
    return HttpClient.post('/api/conversations/$conversationId/messages', body: {'mensaje': text}, auth: true);
  }

  static Future<int> getUnreadConversationsCount() async {
    try {
      final data = await HttpClient.get('/api/conversations/unread-count', auth: true);
      return (data['total'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }
}
