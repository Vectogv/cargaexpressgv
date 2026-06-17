import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

class CacheService {
  static final CacheService instance = CacheService._();
  CacheService._();

  static const String _tripsBox = 'trips';
  static const String _profileBox = 'profile';
  static const String _notificationsBox = 'notifications';
  static const String _chatBox = 'chat';
  static const String _preferencesBox = 'preferences';

  Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(_tripsBox);
    await Hive.openBox(_profileBox);
    await Hive.openBox(_notificationsBox);
    await Hive.openBox(_chatBox);
    await Hive.openBox(_preferencesBox);
  }

  // --- Profile ---

  void cacheProfile(Map<String, dynamic> data) {
    Hive.box(_profileBox).put('profile', jsonEncode(data));
  }

  Map<String, dynamic>? getCachedProfile() {
    final raw = Hive.box(_profileBox).get('profile') as String?;
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  // --- Trips History ---

  void cacheTrips(List<Map<String, dynamic>> trips) {
    Hive.box(_tripsBox).put('history', jsonEncode(trips));
  }

  List<Map<String, dynamic>>? getCachedTrips() {
    final raw = Hive.box(_tripsBox).get('history') as String?;
    if (raw == null) return null;
    final list = jsonDecode(raw) as List;
    return list.cast<Map<String, dynamic>>();
  }

  void cacheActiveTrip(Map<String, dynamic> trip) {
    Hive.box(_tripsBox).put('active', jsonEncode(trip));
  }

  Map<String, dynamic>? getCachedActiveTrip() {
    final raw = Hive.box(_tripsBox).get('active') as String?;
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  void clearActiveTrip() {
    Hive.box(_tripsBox).delete('active');
  }

  // --- Notifications ---

  void cacheNotifications(List<Map<String, dynamic>> notifications) {
    Hive.box(_notificationsBox).put('list', jsonEncode(notifications));
  }

  List<Map<String, dynamic>>? getCachedNotifications() {
    final raw = Hive.box(_notificationsBox).get('list') as String?;
    if (raw == null) return null;
    final list = jsonDecode(raw) as List;
    return list.cast<Map<String, dynamic>>();
  }

  // --- Chat ---

  void cacheMessages(String tripId, List<Map<String, dynamic>> messages) {
    Hive.box(_chatBox).put(tripId, jsonEncode(messages));
  }

  List<Map<String, dynamic>>? getCachedMessages(String tripId) {
    final raw = Hive.box(_chatBox).get(tripId) as String?;
    if (raw == null) return null;
    final list = jsonDecode(raw) as List;
    return list.cast<Map<String, dynamic>>();
  }

  // --- Preferences ---

  void setPreference(String key, dynamic value) {
    Hive.box(_preferencesBox).put(key, value);
  }

  dynamic getPreference(String key) {
    return Hive.box(_preferencesBox).get(key);
  }

  // --- Clear all ---

  Future<void> clearAll() async {
    await Hive.box(_tripsBox).clear();
    await Hive.box(_profileBox).clear();
    await Hive.box(_notificationsBox).clear();
    await Hive.box(_chatBox).clear();
  }
}
