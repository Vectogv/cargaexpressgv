import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'api_client.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  IO.Socket? _socket;
  final List<Map<String, dynamic>> _notifications = [];
  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  bool _initialized = false;
  String? _fcmToken;

  List<Map<String, dynamic>> get notifications => List.unmodifiable(_notifications);

  int get unreadCount => _notifications.where((n) => n['read'] != true).length;

  Stream<Map<String, dynamic>> get onNotification => _controller.stream;

  String? get fcmToken => _fcmToken;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    await _initFcm();
    _initSocket();
  }

  Future<void> _initFcm() async {
    try {
      final messaging = FirebaseMessaging.instance;

      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      _fcmToken = await messaging.getToken();

      if (_fcmToken != null) {
        await _registerToken(_fcmToken!);
      }

      messaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        _registerToken(newToken);
      });

      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }
    } catch (_) {}
  }

  Future<void> _registerToken(String token) async {
    try {
      final authToken = ApiClient.instance.token;
      if (authToken == null) return;

      await http.put(
        Uri.parse('${ApiClient.baseUrl}/api/users/fcm-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({'fcmToken': token}),
      );
    } catch (_) {}
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final notif = message.notification;
    final data = <String, dynamic>{
      if (notif?.title != null) 'title': notif!.title,
      if (notif?.body != null) 'body': notif!.body,
      if (message.data.isNotEmpty) ...message.data,
      '__source': 'fcm',
    };
    _notifications.insert(0, data);
    _controller.add(data);
  }

  void _handleNotificationTap(RemoteMessage message) {
    final notif = message.notification;
    final data = <String, dynamic>{
      if (notif?.title != null) 'title': notif!.title,
      if (notif?.body != null) 'body': notif!.body,
      if (message.data.isNotEmpty) ...message.data,
      '__source': 'fcm',
      '__tap': true,
    };
    _controller.add(data);
  }

  void _initSocket() {
    final token = ApiClient.instance.token;
    final baseUrl = ApiClient.baseUrl;

    if (token == null) return;

    _socket = IO.io(baseUrl, <String, dynamic>{
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

    final driverEvents = [
      'trip:accepted',
      'trip:nearby',
      'driver:stop_gps',
    ];

    void handleEvent(Map<String, dynamic> data, String event) {
      final notification = Map<String, dynamic>.from(data);
      notification['__event'] = event;
      notification['__source'] = 'socket';
      _notifications.insert(0, notification);
      _controller.add(notification);
    }

    for (final event in [...adminEvents, ...driverEvents]) {
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

