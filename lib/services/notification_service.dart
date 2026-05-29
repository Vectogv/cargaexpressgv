import '../models/notification.dart';
import 'api_client.dart';

class NotificationService {
  final ApiClient _api = ApiClient();

  Future<List<AppNotification>> getAll() async {
    final res = await _api.getList('/notifications');
    return res.map((e) => AppNotification.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> markAsRead(String id) async {
    await _api.put('/notifications/$id/read');
  }
}
