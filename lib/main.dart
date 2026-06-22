import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'package:provider/provider.dart';
import 'services/api_client.dart';
import 'services/map_config.dart';
import 'services/notification_service.dart';
import 'services/socket_service_client.dart';
import 'services/dio_client.dart';
import 'services/cache_service.dart';
import 'services/analytics_service.dart';
import 'services/logger_service.dart';
import 'services/network_monitor_service.dart';
import 'services/app_lifecycle_service.dart';
import 'services/error_handler_service.dart';
import 'services/session_monitor_service.dart';
import 'providers/notification_provider.dart';
import 'screens/user/auth_screen.dart';
import 'screens/admin/admin_live_screen.dart';
import 'screens/conductor/home_screen.dart' as conductor;
import 'screens/cliente/home_screen.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (e) {
    LoggerService.instance.error('_firebaseMessagingBackgroundHandler init error', e);
  }

  final data = message.data;
  if (data['type'] == 'new_trip' || data['event'] == 'trip:nearby') {
    return;
  }

  LoggerService.instance.info(
    'Background FCM: ${data['type'] ?? data['event']}',
  );
}

Widget _homeScreenByRole() {
  final rol = ApiClient.instance.rol;
  switch (rol) {
    case 'admin':
      return const AdminLiveScreen();
    case 'conductor':
      return const conductor.HomeScreen();
    case 'cliente':
      return const ClienteHomeScreen();
    default:
      return const AuthScreen();
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    LoggerService.instance.error('Flutter framework error: ${details.exception}', details.exception, details.stack);
    if (!kIsWeb) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(details)
        .catchError((_) {});
    }
  };

  ui.PlatformDispatcher.instance.onError = (error, stack) {
    LoggerService.instance.error('Platform error', error, stack);
    if (!kIsWeb) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true)
        .catchError((_) {});
    }
    return true;
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    LoggerService.instance.error('ErrorWidget: ${details.exception}', details.exception, details.stack);
    return Material(
      color: const Color(0xFFF5F7FA),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.orange),
              const SizedBox(height: 16),
              const Text(
                'Ocurri\u00f3 un error inesperado',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'La aplicaci\u00f3n se recuperar\u00e1 autom\u00e1ticamente.',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  };

  ErrorHandlerService.instance.init();

  unawaited(_initServices().then((_) {
    _loadConfig();
    _recoverSession();
    if (ApiClient.instance.token != null) {
      SessionMonitorService.instance.start();
    }
  }));

  runZonedGuarded(() {
    runApp(const MainApp());
  }, (error, stack) {
    LoggerService.instance.error('Unhandled zone error: $error', error, stack);
    if (!kIsWeb) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true)
        .catchError((_) {});
    }
  });
}

Future<void> _initServices() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    try {
      await Firebase.initializeApp();
    } catch (_) {}
  }

  try {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    LoggerService.instance.error('Firebase background handler error', e);
  }

  try {
    await ApiClient.instance.init();
  } catch (e) {
    LoggerService.instance.error('ApiClient init error', e);
  }

  try {
    await CacheService.instance.init();
  } catch (e) {
    LoggerService.instance.error('CacheService init error', e);
  }

  try {
    DioClient.instance.init();
  } catch (e) {
    LoggerService.instance.error('DioClient init error', e);
  }

  try {
    await AnalyticsService.instance.init();
  } catch (e) {
    LoggerService.instance.error('AnalyticsService init error', e);
  }

  try {
    await NetworkMonitorService.instance.init();
  } catch (e) {
    LoggerService.instance.error('NetworkMonitorService init error', e);
  }

  try {
    AppLifecycleService.instance.init();
  } catch (e) {
    LoggerService.instance.error('AppLifecycleService init error', e);
  }

  try {
    if (ApiClient.instance.token != null) {
      NotificationProvider.instance.init();
    }
  } catch (e) {
    LoggerService.instance.error('NotificationProvider init error', e);
  }

  unawaited(NotificationService.instance.init().catchError((e, s) {
    LoggerService.instance.error('NotificationService init error', e, s);
  }));

  unawaited(SocketServiceClient.instance.init().catchError((e, s) {
    LoggerService.instance.error('SocketServiceClient init error', e, s);
  }));
}

void _recoverSession() {
  final token = ApiClient.instance.token;
  if (token != null) {
    LoggerService.instance.info('Session recovered for user: ${ApiClient.instance.userId}');
    AnalyticsService.instance.setUserId(ApiClient.instance.userId ?? 'unknown');
    AnalyticsService.instance.logEvent('session_recovered');

    final cachedTrip = CacheService.instance.getCachedActiveTrip();
    if (cachedTrip != null) {
      LoggerService.instance.info('Cached active trip found: ${cachedTrip['id']}');
    }
  }
}

Future<void> _loadConfig() async {
  try {
    final token = await ApiClient.instance.fetchMapboxToken();
    MapConfig.mapboxAccessToken = token;
  } catch (e) {
    LoggerService.instance.debug('Mapbox token not available, using OSM fallback');
  }
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: NotificationProvider.instance),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'CargaExpress',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.black),
          useMaterial3: true,
        ),
        home: ApiClient.instance.token != null
            ? _homeScreenByRole()
            : const AuthScreen(),
      ),
    );
  }
}
