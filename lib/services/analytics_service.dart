import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'logger_service.dart';

class AnalyticsService {
  static final AnalyticsService instance = AnalyticsService._();
  AnalyticsService._();

  bool _initialized = false;
  bool _firebaseAvailable = false;

  FirebaseAnalytics? _analytics;
  FirebaseAnalytics? get analytics => _analytics;

  FirebaseCrashlytics? _crashlytics;
  FirebaseCrashlytics? get crashlytics => _crashlytics;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      _analytics = FirebaseAnalytics.instance;
      _firebaseAvailable = true;
      if (!kIsWeb) {
        _crashlytics = FirebaseCrashlytics.instance;
      }
    } catch (_) {
      _firebaseAvailable = false;
    }

    FlutterError.onError = (details) {
      LoggerService.instance.error('Flutter error: ${details.exception}', details.exception, details.stack);
      if (details.stack != null) {
        recordError(details.exception, details.stack!);
      }
    };

    ui.PlatformDispatcher.instance.onError = (error, stack) {
      LoggerService.instance.error('Platform error', error, stack);
      recordError(error, stack);
      return true;
    };

    runZonedGuarded(() {
      LoggerService.instance.info('AnalyticsService initialized (web: $kIsWeb, firebase: $_firebaseAvailable)');
    }, (error, stack) {
      LoggerService.instance.error('Unhandled zone error', error, stack);
    });
  }

  Future<void> logScreen(String screenName) async {
    if (!_firebaseAvailable) return;
    try {
      await _analytics!.logScreenView(screenName: screenName);
    } catch (e) {
      LoggerService.instance.error('logScreen error', e);
    }
  }

  Future<void> logEvent(String name, {Map<String, dynamic>? parameters}) async {
    if (!_firebaseAvailable) return;
    try {
      await _analytics!.logEvent(name: name, parameters: parameters?.cast<String, Object>());
    } catch (e) {
      LoggerService.instance.error('logEvent error', e);
    }
  }

  Future<void> recordError(dynamic error, StackTrace stack) async {
    LoggerService.instance.error('recordError', error, stack);
    if (!_firebaseAvailable) return;
    try {
      await _crashlytics!.recordError(error, stack);
    } catch (_) {}
  }

  Future<void> setUserId(String userId) async {
    if (!_firebaseAvailable) return;
    try {
      await _crashlytics!.setUserIdentifier(userId);
    } catch (_) {}
  }
}
