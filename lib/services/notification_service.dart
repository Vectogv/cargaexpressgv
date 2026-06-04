import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'api_client.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  IO.Socket? _socket;
  final List<Map<String, dynamic>> _notifications = [];
  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  bool _initialized = false;

  List<Map<String, dynamic>> get notifications => List.unmodifiable(_notifications);

  int get unreadCount => _notifications.where((n) => n['read'] != true).length;

  Stream<Map<String, dynamic>> get onNotification => _controller.stream;

  void init() {
    if (_initialized) return;
    _initialized = true;

    final token = ApiClient.instance.token;
    final baseUrl = ApiClient.baseUrl;

    if (token == null) return;

    _socket = IO.io('$baseUrl', <String, dynamic>{
      'transports': ['websocket'],
      'query': {'token': token},
    });

    _socket!.on('connect', (_) {});

    _socket!.on('disconnect', (_) {});

    final adminEvents = [
      'admin:new_user',
      'admin:new_driver',
      'admin:new_trip',
      'admin:trip_completed',
      'admin:payment_received',
      'admin:user_banned',
      'admin:driver_approved',
      'admin:report',
    ];

    void handleEvent(Map<String, dynamic> data, String event) {
      final notification = Map<String, dynamic>.from(data);
      notification['__event'] = event;
      _notifications.insert(0, notification);
      _controller.add(notification);
    }

    for (final event in adminEvents) {
      _socket!.on(event, (data) {
        handleEvent(Map<String, dynamic>.from(data as Map), event);
      });
    }
  }

  void markAllRead() {
    for (int i = 0; i < _notifications.length; i++) {
      _notifications[i]['read'] = true;
    }
  }

  void dispose() {
    _socket?.disconnect();
    _socket?.dispose();
    _controller.close();
  }
}
