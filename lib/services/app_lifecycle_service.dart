import 'dart:async';
import 'package:flutter/material.dart';
import 'logger_service.dart';
import 'socket_service_client.dart';
import 'network_monitor_service.dart';
import 'driver_location_service.dart';
import 'cache_service.dart';

class AppLifecycleService with WidgetsBindingObserver {
  static final AppLifecycleService instance = AppLifecycleService._();
  AppLifecycleService._();

  bool _initialized = false;
  AppLifecycleState? _lastState;

  final _backgroundCtrl = StreamController<bool>.broadcast();
  Stream<bool> get onBackgroundChanged => _backgroundCtrl.stream;
  bool get isInBackground => _lastState == AppLifecycleState.paused || _lastState == AppLifecycleState.inactive;

  void init() {
    if (_initialized) return;
    _initialized = true;
    WidgetsBinding.instance.addObserver(this);
    LoggerService.instance.info('AppLifecycleService initialized');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lastState = state;
    LoggerService.instance.info('App lifecycle: $state');

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _onBackground();
      case AppLifecycleState.resumed:
        _onForeground();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  void _onBackground() {
    LoggerService.instance.info('App went to background');
    _backgroundCtrl.add(true);
  }

  void _onForeground() {
    LoggerService.instance.info('App returned to foreground');
    _backgroundCtrl.add(false);

    _restoreConnections();
  }

  void _restoreConnections() {
    if (SocketServiceClient.instance.isConnected) {
      LoggerService.instance.info('Lifecycle: socket already connected');
    } else {
      LoggerService.instance.info('Lifecycle: reconnecting socket');
      SocketServiceClient.instance.forceReconnect();
    }

    if (!NetworkMonitorService.instance.isOnline) {
      LoggerService.instance.info('Lifecycle: waiting for network');
    }
  }

  Future<void> onResumeWithTrip(Map<String, dynamic>? currentTrip) async {
    LoggerService.instance.info('Lifecycle: restoring trip state');

    if (currentTrip != null) {
      CacheService.instance.cacheActiveTrip(currentTrip);
      return;
    }

    final cached = CacheService.instance.getCachedActiveTrip();
    if (cached != null) {
      LoggerService.instance.info('Lifecycle: found cached active trip');
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _backgroundCtrl.close();
  }
}
