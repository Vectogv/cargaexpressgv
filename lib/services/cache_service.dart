import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'logger_service.dart';

class CacheService {
  static final CacheService instance = CacheService._();
  CacheService._();

  static const String _tripsBox = 'trips';
  static const String _profileBox = 'profile';
  static const String _notificationsBox = 'notifications';
  static const String _chatBox = 'chat';
  static const String _preferencesBox = 'preferences';

  Future<void> init() async {
    try {
      await Hive.initFlutter();
      await Hive.openBox(_tripsBox);
      await Hive.openBox(_profileBox);
      await Hive.openBox(_notificationsBox);
      await Hive.openBox(_chatBox);
      await Hive.openBox(_preferencesBox);
      LoggerService.instance.info('CacheService initialized');
    } catch (e) {
      LoggerService.instance.error('CacheService.init error', e);
    }
  }

  // --- Profile ---

  void cacheProfile(Map<String, dynamic> data) {
    try {
      Hive.box(_profileBox).put('profile', jsonEncode(data));
    } catch (e) {
      LoggerService.instance.error('CacheService.cacheProfile error', e);
    }
  }

  Map<String, dynamic>? getCachedProfile() {
    try {
      final raw = Hive.box(_profileBox).get('profile') as String?;
      if (raw == null) return null;
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      LoggerService.instance.error('CacheService.getCachedProfile error', e);
      return null;
    }
  }

  // --- Trips History ---

  void cacheTrips(List<Map<String, dynamic>> trips) {
    try {
      Hive.box(_tripsBox).put('history', jsonEncode(trips));
    } catch (e) {
      LoggerService.instance.error('CacheService.cacheTrips error', e);
    }
  }

  List<Map<String, dynamic>>? getCachedTrips() {
    try {
      final raw = Hive.box(_tripsBox).get('history') as String?;
      if (raw == null) return null;
      final list = jsonDecode(raw) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (e) {
      LoggerService.instance.error('CacheService.getCachedTrips error', e);
      return null;
    }
  }

  void cacheActiveTrip(Map<String, dynamic> trip) {
    try {
      Hive.box(_tripsBox).put('active', jsonEncode(trip));
    } catch (e) {
      LoggerService.instance.error('CacheService.cacheActiveTrip error', e);
    }
  }

  Map<String, dynamic>? getCachedActiveTrip() {
    try {
      final raw = Hive.box(_tripsBox).get('active') as String?;
      if (raw == null) return null;
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      LoggerService.instance.error('CacheService.getCachedActiveTrip error', e);
      return null;
    }
  }

  void clearActiveTrip() {
    try {
      Hive.box(_tripsBox).delete('active');
    } catch (e) {
      LoggerService.instance.error('CacheService.clearActiveTrip error', e);
    }
  }

  // --- Notifications ---

  void cacheNotifications(List<Map<String, dynamic>> notifications) {
    try {
      Hive.box(_notificationsBox).put('list', jsonEncode(notifications));
    } catch (e) {
      LoggerService.instance.error('CacheService.cacheNotifications error', e);
    }
  }

  List<Map<String, dynamic>>? getCachedNotifications() {
    try {
      final raw = Hive.box(_notificationsBox).get('list') as String?;
      if (raw == null) return null;
      final list = jsonDecode(raw) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (e) {
      LoggerService.instance.error('CacheService.getCachedNotifications error', e);
      return null;
    }
  }

  // --- Chat ---

  void cacheMessages(String tripId, List<Map<String, dynamic>> messages) {
    try {
      final limited = messages.length > 100 ? messages.sublist(messages.length - 100) : messages;
      Hive.box(_chatBox).put(tripId, jsonEncode(limited));
    } catch (e) {
      LoggerService.instance.error('CacheService.cacheMessages error', e);
    }
  }

  List<Map<String, dynamic>>? getCachedMessages(String tripId) {
    try {
      final raw = Hive.box(_chatBox).get(tripId) as String?;
      if (raw == null) return null;
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.cast<Map<String, dynamic>>();
    } catch (e) {
      LoggerService.instance.error('CacheService.getCachedMessages error', e);
      return null;
    }
  }

  // --- Driver Position ---

  void cacheDriverPosition(double lat, double lng) {
    try {
      Hive.box(_tripsBox).put('driverPos', jsonEncode({'lat': lat, 'lng': lng}));
    } catch (e) {
      LoggerService.instance.error('CacheService.cacheDriverPosition error', e);
    }
  }

  Map<String, dynamic>? getCachedDriverPosition() {
    try {
      final raw = Hive.box(_tripsBox).get('driverPos') as String?;
      if (raw == null) return null;
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      LoggerService.instance.error('CacheService.getCachedDriverPosition error', e);
      return null;
    }
  }

  void clearDriverPosition() {
    try {
      Hive.box(_tripsBox).delete('driverPos');
    } catch (e) {
      LoggerService.instance.error('CacheService.clearDriverPosition error', e);
    }
  }

  // --- Preferences ---

  void setPreference(String key, dynamic value) {
    try {
      Hive.box(_preferencesBox).put(key, value);
    } catch (e) {
      LoggerService.instance.error('CacheService.setPreference error', e);
    }
  }

  dynamic getPreference(String key) {
    try {
      return Hive.box(_preferencesBox).get(key);
    } catch (e) {
      LoggerService.instance.error('CacheService.getPreference error', e);
      return null;
    }
  }

  // --- Clear all ---

  Future<void> clearAll() async {
    try {
      await Hive.box(_tripsBox).clear();
      await Hive.box(_profileBox).clear();
      await Hive.box(_notificationsBox).clear();
      await Hive.box(_chatBox).clear();
    } catch (e) {
      LoggerService.instance.error('CacheService.clearAll error', e);
    }
  }
}
