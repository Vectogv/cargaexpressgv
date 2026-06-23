import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'api_client.dart';
import 'logger_service.dart';
import 'network_monitor_service.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  IO.Socket? _socket;
  final List<Map<String, dynamic>> _notifications = [];
  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  bool _initialized = false;
  String? _fcmToken;
  final Set<String> _processedTripIds = {};

  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 50;
  Timer? _reconnectTimer;
  StreamSubscription<bool>? _networkSub;

  List<Map<String, dynamic>> get notifications => List.unmodifiable(_notifications);

  int get unreadCount => _notifications.where((n) => n['read'] != true).length;

  Stream<Map<String, dynamic>> get onNotification => _controller.stream;

  String? get fcmToken => _fcmToken;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    _networkSub = NetworkMonitorService.instance.onConnectionChanged.listen((online) {
      if (online && _socket != null && !(_socket!.connected)) {
        LoggerService.instance.info('NotificationService: network restored, reconnecting socket');
        _scheduleReconnect();
      }
    });

    await _initFcm();
    _initSocket();
  }

  Future<void> _initFcm() async {
    if (kIsWeb) return;
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
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({'fcmToken': token}),
      );
    } catch (e) {
      LoggerService.instance.error('NotificationService._registerToken error', e);
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final notif = message.notification;
    final data = message.data;

    if (data['type'] == 'new_trip' || data['event'] == 'trip:nearby') {
      final tripId = data['tripId'] ?? data['id'];
      if (tripId != null && _processedTripIds.contains(tripId.toString())) return;
      if (tripId != null) _processedTripIds.add(tripId.toString());
    }

    final entry = <String, dynamic>{
      if (notif?.title != null) 'title': notif!.title,
      if (notif?.body != null) 'body': notif!.body,
      if (data.isNotEmpty) ...data,
      '__source': 'fcm',
    };
    _notifications.insert(0, entry);
    _controller.add(entry);
  }

  void _handleNotificationTap(RemoteMessage message) {
    final notif = message.notification;
    final data = message.data;

    final entry = <String, dynamic>{
      if (notif?.title != null) 'title': notif!.title,
      if (notif?.body != null) 'body': notif!.body,
      if (data.isNotEmpty) ...data,
      '__source': 'fcm',
      '__tap': true,
    };

    if (data['type'] == 'new_trip' || data['event'] == 'trip:nearby') {
      entry['__navigate'] = 'offers';
    }

    _controller.add(entry);
  }

  void _initSocket() {
    final token = ApiClient.instance.token;
    final baseUrl = ApiClient.baseUrl;

    if (token == null) return;

    try {
      _socket?.dispose();
      _socket = IO.io(baseUrl, <String, dynamic>{
        'transports': ['websocket'],
        'query': {'token': token},
        'forceNew': true,
        'reconnection': false,
      });

      _socket!.on('connect', (_) {
        _reconnectAttempts = 0;
        LoggerService.instance.info('NotificationService socket connected');
        final userId = ApiClient.instance.userId;
        if (userId != null) {
          _socket!.emit('join:client', {'userId': userId});
        }
      });

      _socket!.on('disconnect', (_) {
        LoggerService.instance.warning('NotificationService socket disconnected');
        _scheduleReconnect();
      });

      _socket!.on('connect_error', (error) {
        LoggerService.instance.error('NotificationService socket connect_error', error);
        _scheduleReconnect();
      });

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
        'trip:cancelled',
        'driver:stop_gps',
      ];

      void handleEvent(Map<String, dynamic> data, String event) {
        final notification = Map<String, dynamic>.from(data);
        notification['__event'] = event;
        notification['__source'] = 'socket';

        if (event == 'trip:nearby') {
          final tripId = data['tripId'] ?? data['id'];
          if (tripId != null && _processedTripIds.contains(tripId.toString())) return;
          if (tripId != null) _processedTripIds.add(tripId.toString());
          _notifications.insert(0, notification);
          _controller.add(notification);
        } else if (event == 'trip:accepted') {
          _notifications.insert(0, notification);
          _controller.add(notification);
        } else {
          _notifications.insert(0, notification);
          _controller.add(notification);
        }
      }

      void safeOn(String event, void Function(dynamic) handler) {
        _socket!.on(event, (data) {
          try {
            handler(data);
          } catch (e, s) {
            LoggerService.instance.error('NotificationService socket event "$event" error', e, s);
          }
        });
      }

      for (final ev in [...adminEvents, ...driverEvents]) {
        safeOn(ev, (data) {
          if (data is Map) {
            handleEvent(Map<String, dynamic>.from(data), ev);
          }
        });
      }
    } catch (e) {
      LoggerService.instance.error('NotificationService._initSocket error', e);
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      LoggerService.instance.warning('NotificationService: max reconnect attempts reached');
      return;
    }

    if (!NetworkMonitorService.instance.isOnline) {
      return;
    }

    _reconnectAttempts++;
    final delay = Duration(milliseconds: min(1000 * pow(2, _reconnectAttempts).toInt(), 30000));

    _reconnectTimer = Timer(delay, () {
      if (ApiClient.instance.token != null) {
        _initSocket();
      }
    });
  }

  void clearDuplicateTracking() {
    _processedTripIds.clear();
  }

  void markAllRead() {
    for (int i = 0; i < _notifications.length; i++) {
      _notifications[i]['read'] = true;
    }
  }

  void dispose() {
    _reconnectTimer?.cancel();
    _networkSub?.cancel();
    _socket?.disconnect();
    _socket?.dispose();
    _controller.close();
  }
}
