import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'api_client.dart';
import 'socket_service_client.dart';
import 'logger_service.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final List<Map<String, dynamic>> _notifications = [];
  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  bool _initialized = false;
  String? _fcmToken;
  final Set<String> _processedTripIds = {};

  // Subscripciones a SocketServiceClient (reemplaza el socket propio)
  StreamSubscription<Map<String, dynamic>>? _tripStatusSub;
  StreamSubscription<Map<String, dynamic>>? _tripAcceptedSub;
  StreamSubscription<Map<String, dynamic>>? _tripCancelledSub;
  StreamSubscription<Map<String, dynamic>>? _tripDeliveredSub;
  StreamSubscription<Map<String, dynamic>>? _sosActivatedSub;
  StreamSubscription<Map<String, dynamic>>? _notificationSub;

  List<Map<String, dynamic>> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _notifications.where((n) => n['read'] != true).length;
  Stream<Map<String, dynamic>> get onNotification => _controller.stream;
  String? get fcmToken => _fcmToken;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    await _initFcm();
    _subscribeToSocketService();
  }

  // En lugar de abrir un socket propio, escuchar del SocketServiceClient existente
  void _subscribeToSocketService() {
    _tripStatusSub = SocketServiceClient.instance.onTripStatus.listen((data) {
      _addNotification({...data, '__event': 'trip:status'});
    });

    _tripAcceptedSub = SocketServiceClient.instance.onTripAccepted.listen((data) {
      _addNotification({...data, '__event': 'trip:accepted'});
    });

    _tripCancelledSub = SocketServiceClient.instance.onTripCancelled.listen((data) {
      _addNotification({...data, '__event': 'trip:cancelled'});
    });

    _tripDeliveredSub = SocketServiceClient.instance.onTripDelivered.listen((data) {
      _addNotification({...data, '__event': 'trip:delivered'});
    });

    _sosActivatedSub = SocketServiceClient.instance.onSosActivated.listen((data) {
      _addNotification({...data, '__event': 'sos:activated'});
    });

    _notificationSub = SocketServiceClient.instance.onNotification.listen((data) {
      final event = data['__event'] as String? ?? '';

      if (event == 'trip:nearby') {
        final tripId = (data['tripId'] ?? data['id'])?.toString();
        if (tripId != null && _processedTripIds.contains(tripId)) return;
        if (tripId != null) _processedTripIds.add(tripId);
      }

      _addNotification(data);
    });
  }

  void _addNotification(Map<String, dynamic> data) {
    _notifications.insert(0, data);
    if (!_controller.isClosed) _controller.add(data);
  }

  Future<void> _initFcm() async {
    if (kIsWeb) return;
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      _fcmToken = await messaging.getToken();
      if (_fcmToken != null) await _registerToken(_fcmToken!);

      messaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        _registerToken(newToken);
      });

      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) _handleNotificationTap(initialMessage);
    } catch (e) {
      LoggerService.instance.error('NotificationService._initFcm error', e);
    }
  }

  Future<void> _registerToken(String token) async {
    try {
      final authToken = ApiClient.instance.token;
      if (authToken == null) return;
      await http.put(
        Uri.parse('${ApiClient.baseUrl}/api/users/fcm-token'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $authToken'},
        body: jsonEncode({'fcmToken': token}),
      );
    } catch (e) {
      LoggerService.instance.error('NotificationService._registerToken error', e);
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final data = message.data;
    if (data['type'] == 'new_trip' || data['event'] == 'trip:nearby') {
      final tripId = data['tripId'] ?? data['id'];
      if (tripId != null && _processedTripIds.contains(tripId.toString())) return;
      if (tripId != null) _processedTripIds.add(tripId.toString());
    }
    final entry = <String, dynamic>{
      if (message.notification?.title != null) 'title': message.notification!.title,
      if (message.notification?.body != null) 'body': message.notification!.body,
      if (data.isNotEmpty) ...data,
      '__source': 'fcm',
    };
    _addNotification(entry);
  }

  void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    final entry = <String, dynamic>{
      if (message.notification?.title != null) 'title': message.notification!.title,
      if (message.notification?.body != null) 'body': message.notification!.body,
      if (data.isNotEmpty) ...data,
      '__source': 'fcm',
      '__tap': true,
    };
    if (data['type'] == 'new_trip' || data['event'] == 'trip:nearby') {
      entry['__navigate'] = 'offers';
    }
    _addNotification(entry);
  }

  void clearDuplicateTracking() => _processedTripIds.clear();

  void markAllRead() {
    for (int i = 0; i < _notifications.length; i++) {
      _notifications[i]['read'] = true;
    }
  }

  void dispose() {
    _tripStatusSub?.cancel();
    _tripAcceptedSub?.cancel();
    _tripCancelledSub?.cancel();
    _tripDeliveredSub?.cancel();
    _sosActivatedSub?.cancel();
    _notificationSub?.cancel();
    _controller.close();
  }
}
