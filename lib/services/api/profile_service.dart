import 'dart:typed_data';
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

  static Future<List<Map<String, dynamic>>> getNotifications() async {
    final list = await HttpClient.getList('/api/notifications', auth: true);
    return list.cast<Map<String, dynamic>>();
  }

  static Future<void> markNotificationRead(dynamic id) async {
    await HttpClient.put('/api/notifications/$id/read', auth: true);
  }

  static Future<List<Map<String, dynamic>>> getForumPosts() async {
    final list = await HttpClient.getList('/api/foro', auth: true);
    return list.cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> createForumPost(Map<String, dynamic> data) async {
    return HttpClient.post('/api/foro', body: data, auth: true);
  }

  static Future<Map<String, dynamic>> getSurveyResults(dynamic id) async {
    return HttpClient.get('/api/moderator/encuestas/$id/results', auth: true);
  }

  static Future<void> answerSurvey(dynamic id, dynamic opcionId) async {
    await HttpClient.post('/api/moderator/encuestas/$id/answer', body: {'opcionId': opcionId}, auth: true);
  }

  static Future<Map<String, dynamic>> getSettings() async {
    return HttpClient.get('/api/settings', auth: true);
  }

  static Future<Map<String, dynamic>> updateSettings(Map<String, dynamic> data) async {
    return HttpClient.put('/api/settings', body: data, auth: true);
  }

  static Future<Map<String, dynamic>> getHelp() async {
    return HttpClient.get('/api/support/help', auth: true);
  }

  static Future<Map<String, dynamic>> getEmergencyNumbers() async {
    return HttpClient.get('/api/support/emergency', auth: true);
  }

  static Future<String> fetchMapboxToken() async {
    final data = await HttpClient.get('/api/config/mapbox', auth: true);
    return data['mapboxAccessToken'] as String;
  }
}
