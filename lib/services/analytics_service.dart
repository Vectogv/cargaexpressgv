import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'logger_service.dart';

class AnalyticsService {
  static final AnalyticsService instance = AnalyticsService._();
  AnalyticsService._();

  final FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  final FirebaseCrashlytics crashlytics = FirebaseCrashlytics.instance;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    FlutterError.onError = (details) {
      LoggerService.instance.error('Flutter error: ${details.exception}', details.exception, details.stack);
      crashlytics.recordFlutterFatalError(details);
    };

    ui.PlatformDispatcher.instance.onError = (error, stack) {
      LoggerService.instance.error('Platform error', error, stack);
      crashlytics.recordError(error, stack, fatal: true);
      return true;
    };

    runZonedGuarded(() {
      LoggerService.instance.info('AnalyticsService initialized');
    }, (error, stack) {
      LoggerService.instance.error('Unhandled zone error', error, stack);
      crashlytics.recordError(error, stack, fatal: true);
    });
  }

  Future<void> logScreen(String screenName) async {
    try {
      await analytics.logScreenView(screenName: screenName);
    } catch (e) {
      LoggerService.instance.error('logScreen error', e);
    }
  }

  Future<void> logEvent(String name, {Map<String, dynamic>? parameters}) async {
    try {
      await analytics.logEvent(name: name, parameters: parameters?.cast<String, Object>());
    } catch (e) {
      LoggerService.instance.error('logEvent error', e);
    }
  }

  Future<void> recordError(dynamic error, StackTrace stack) async {
    LoggerService.instance.error('recordError', error, stack);
    await crashlytics.recordError(error, stack);
  }

  Future<void> setUserId(String userId) async {
    await crashlytics.setUserIdentifier(userId);
  }
}
