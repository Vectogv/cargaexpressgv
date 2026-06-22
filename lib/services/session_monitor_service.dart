import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api_client.dart';
import 'cache_service.dart';
import 'logger_service.dart';

class SessionMonitorService {
  static final SessionMonitorService instance = SessionMonitorService._();
  SessionMonitorService._();

  Timer? _healthCheckTimer;
  bool _running = false;
  static const Duration _checkInterval = Duration(minutes: 5);

  void start() {
    if (_running) return;
    _running = true;
    _healthCheckTimer = Timer.periodic(_checkInterval, (_) => _checkHealth());
    LoggerService.instance.info('SessionMonitorService started');
  }

  void stop() {
    _running = false;
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
  }

  @visibleForTesting
  Future<void> checkHealth({ApiClient? client, CacheService? cache}) async {
    await _checkHealth(client: client, cache: cache);
  }

  Future<void> _checkHealth({ApiClient? client, CacheService? cache}) async {
    final apiClient = client ?? ApiClient.instance;
    final cacheService = cache ?? CacheService.instance;

    if (apiClient.token == null) {
      stop();
      return;
    }

    try {
      final profile = await apiClient.getProfile();
      if (profile.isNotEmpty) {
        LoggerService.instance.debug('Session health check: OK');
      }
    } catch (e) {
      LoggerService.instance.warning('Session health check failed, attempting recovery', e);

      try {
        final cached = cacheService.getCachedProfile();
        if (cached != null) {
          LoggerService.instance.info('Session recovered from cache');
        }
      } catch (_) {}

      try {
        await apiClient.refreshToken();
        LoggerService.instance.info('Session token refreshed successfully');
      } catch (e) {
        LoggerService.instance.error('Session recovery failed', e);
      }
    }
  }

  void dispose() {
    stop();
  }
}
