import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  static final AnalyticsService instance = AnalyticsService._();
  AnalyticsService._();

  final FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  final FirebaseCrashlytics crashlytics = FirebaseCrashlytics.instance;

  Future<void> init() async {
    FlutterError.onError = (details) {
      crashlytics.recordFlutterFatalError(details);
    };
    ui.PlatformDispatcher.instance.onError = (error, stack) {
      crashlytics.recordError(error, stack, fatal: true);
      return true;
    };
  }

  Future<void> logScreen(String screenName) async {
    await analytics.logScreenView(screenName: screenName);
  }

  Future<void> logEvent(String name, {Map<String, dynamic>? parameters}) async {
    await analytics.logEvent(name: name, parameters: parameters?.cast<String, Object>());
  }

  Future<void> recordError(dynamic error, StackTrace stack) async {
    await crashlytics.recordError(error, stack);
  }

  Future<void> setUserId(String userId) async {
    await crashlytics.setUserIdentifier(userId);
  }
}
