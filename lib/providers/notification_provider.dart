import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/socket_service_client.dart';
import '../services/cache_service.dart';
import '../services/api/profile_service.dart';
import '../models/notification_item_model.dart';

class NotificationProvider extends ChangeNotifier {
  static final NotificationProvider instance = NotificationProvider._();
  NotificationProvider._();

  List<NotificationItemModel> _items = [];
  StreamSubscription<Map<String, dynamic>>? _sub;
  StreamSubscription<Map<String, dynamic>>? _cancelSub;

  List<NotificationItemModel> get items => List.unmodifiable(_items);
  int get unreadCount => _items.where((n) => n.read != true).length;

  void init() {
    _loadCached();
    _sub = SocketServiceClient.instance.onNotification.listen((data) {
      final item = NotificationItemModel.fromJson(data);
      _items.insert(0, item);
      _saveCache();
      notifyListeners();
    });
    _cancelSub = SocketServiceClient.instance.onTripCancelled.listen((data) {
      final tripId = data['tripId'] ?? data['id'];
      final item = NotificationItemModel(
        id: 'cancel_${tripId}_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Viaje cancelado',
        body: data['motivo'] != null
            ? 'El conductor cancel\u00f3 el viaje: ${data['motivo']}'
            : 'El conductor ha cancelado el viaje',
        type: 'viaje_cancelado',
        read: false,
        data: data,
        createdAt: DateTime.now().toIso8601String(),
      );
      _items.insert(0, item);
      _saveCache();
      notifyListeners();
    });
  }

  void _loadCached() {
    final cached = CacheService.instance.getCachedNotifications();
    if (cached != null) {
      _items = cached.map((e) => NotificationItemModel.fromJson(e)).toList();
      notifyListeners();
    }
  }

  void _saveCache() {
    CacheService.instance.cacheNotifications(_items.map((e) => e.toJson()).toList());
  }

  Future<void> fetchFromBackend() async {
    try {
      final raw = await ProfileService.getNotifications();
      _items = raw.map((e) => NotificationItemModel.fromJson(e)).toList();
      _saveCache();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> markRead(dynamic id) async {
    try {
      await ProfileService.markNotificationRead(id);
    } catch (_) {}
    final idx = _items.indexWhere((n) => n.id == id);
    if (idx != -1) {
      _items[idx] = _items[idx].copyWith(read: true);
      _saveCache();
      notifyListeners();
    }
  }

  void markAllRead() {
    _items = _items.map((n) => n.copyWith(read: true)).toList();
    _saveCache();
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _cancelSub?.cancel();
    super.dispose();
  }
}
