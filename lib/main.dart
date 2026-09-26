import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'services/api_client.dart';
import 'services/map_config.dart';
import 'services/notification_service.dart';
import 'services/socket_service_client.dart';
import 'services/cache_service.dart';
import 'services/analytics_service.dart';
import 'services/logger_service.dart';
import 'services/network_monitor_service.dart';
import 'services/app_lifecycle_service.dart';
import 'services/error_handler_service.dart';
import 'services/session_monitor_service.dart';
import 'services/session_events.dart';
import 'core/navegador_global.dart';
import 'screens/user/auth_screen.dart';
import 'screens/shared/cuenta_no_activa_dialog.dart' show mostrarCuentaSuspendidaDialog;
import 'screens/shared/tickets/tickets_navegacion.dart' show abrirTicketSoporteGlobal;
import 'screens/home_by_role.dart';

final GlobalKey<NavigatorState> _navigatorKey = navegadorGlobal;

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (e) {
    LoggerService.instance.error('_firebaseMessagingBackgroundHandler init error', e);
  }
  final data = message.data;
  if (data['type'] == 'new_trip' || data['event'] == 'trip:nearby') return;
  LoggerService.instance.info('Background FCM: ${data['type'] ?? data['event']}');
}

/// Misma función de ruteo por rol que usan el login y el registro
/// (`screens/home_by_role.dart`), para que restaurar la sesión lleve a la
/// misma pantalla que iniciar sesión.
Widget _homeScreenByRole() => homeScreenFor(homeDestinoForSession());

// ─────────────────────────────────────────────────────────────────────────────
// ENTRY POINT
// Todo corre dentro de runZonedGuarded para que la zona sea única desde el
// inicio. ensureInitialized() también debe vivir en esa misma zona.
// ─────────────────────────────────────────────────────────────────────────────
void main() {
  runZonedGuarded(
    () async {
      // 1. Binding — DENTRO de la zona.
      WidgetsFlutterBinding.ensureInitialized();

      // 2. Handlers de error globales.
      _setupErrorHandlers();

      // Tocar un push de ticket de soporte abre su detalle (también cuando
      // la app estaba cerrada: getInitialMessage corre en init()).
      NotificationService.instance.abrirTicket = abrirTicketSoporteGlobal;

      // 3. Servicios críticos (await — bloqueantes antes del runApp).
      await _initServices();

      // 4. Sesión + config (no bloquean el arranque de la UI).
      _recoverSession();
      unawaited(_loadConfig());
      if (ApiClient.instance.token != null) {
        // Monitor de sesión + permiso y token FCM (antes sólo se registraba
        // al iniciar sesión: con la sesión guardada el backend nunca recibía
        // el token y no llegaban notificaciones).
        iniciarServiciosDeSesion();
      }

      // 5. App.
      runApp(const MainApp());
    },
    (error, stack) {
      LoggerService.instance.error('Unhandled zone error: $error', error, stack);
      if (!kIsWeb) {
        FirebaseCrashlytics.instance
            .recordError(error, stack, fatal: true)
            .catchError((_) {});
      }
    },
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Handlers de error de Flutter / plataforma
// ─────────────────────────────────────────────────────────────────────────────
void _setupErrorHandlers() {
  ErrorHandlerService.instance.init();

  // Sesión expirada (refresh inválido) o cuenta suspendida (403
  // CUENTA_SUSPENDIDA / socket): volver al login limpiando la pila completa y
  // mostrar el motivo. ErrorHandlerService.emitSessionExpired() también
  // publica aquí. Varios eventos seguidos se colapsan en uno.
  SessionEvents.instance.stream.listen(_onSessionEvent);

  FlutterError.onError = (details) {
    LoggerService.instance.error(
      'Flutter framework error: ${details.exception}',
      details.exception,
      details.stack,
    );
    if (!kIsWeb) {
      FirebaseCrashlytics.instance
          .recordFlutterFatalError(details)
          .catchError((_) {});
    }
  };

  ui.PlatformDispatcher.instance.onError = (error, stack) {
    LoggerService.instance.error('Platform error', error, stack);
    if (!kIsWeb) {
      FirebaseCrashlytics.instance
          .recordError(error, stack, fatal: true)
          .catchError((_) {});
    }
    return true;
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    LoggerService.instance.error(
      'ErrorWidget: ${details.exception}',
      details.exception,
      details.stack,
    );
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
                'Ocurrió un error inesperado',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'La aplicación se recuperará automáticamente.',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  };
}

final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
DateTime? _lastSessionEventAt;

Future<void> _onSessionEvent(SessionEvent event) async {
  final now = DateTime.now();
  if (_lastSessionEventAt != null &&
      now.difference(_lastSessionEventAt!) < const Duration(seconds: 3)) {
    return;
  }
  _lastSessionEventAt = now;
  LoggerService.instance.info('Session event: ${event.type}');

  SessionMonitorService.instance.stop();
  if (ApiClient.instance.token != null) {
    try {
      await ApiClient.instance.clearTokens();
    } catch (e) {
      LoggerService.instance.error('clearTokens on session event failed', e);
    }
  }

  final nav = _navigatorKey.currentState;
  if (nav == null) return;
  nav.pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const AuthScreen()),
    (route) => false,
  );

  final suspended = event.type == SessionEventType.suspended;
  final message = (event.message != null && event.message!.trim().isNotEmpty)
      ? event.message!
      : suspended
          ? 'Tu cuenta está suspendida. Contacta a soporte.'
          : 'Tu sesión expiró. Inicia sesión nuevamente.';
  final messenger = _scaffoldMessengerKey.currentState;
  messenger?.hideCurrentSnackBar();
  if (suspended) {
    // Suspensión del administrador (no por pago): diálogo con acceso a
    // Soporte sobre la bienvenida, en vez de un aviso que desaparece.
    final ctx = nav.overlay?.context;
    if (ctx != null && ctx.mounted) {
      unawaited(mostrarCuentaSuspendidaDialog(ctx, message));
      return;
    }
  }
  messenger?.showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: suspended ? Colors.red.shade700 : null,
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: suspended ? 8 : 4),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Inicialización de servicios — todos awaited en secuencia.
// Los que pueden fallar de forma aislada se envuelven en try/catch.
// Los que no bloquean el arranque se lanzan con unawaited al final.
// ─────────────────────────────────────────────────────────────────────────────
Future<void> _initServices() async {
  // Firebase — intentar con opciones de plataforma, si falla reintentar sin.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e1) {
    try {
      await Firebase.initializeApp();
    } catch (e) {
      LoggerService.instance.error('Firebase init failed', e);
      // Se informa al backend si luego no hay token FCM (diagnóstico).
      NotificationService.instance.errorInicioFirebase = 'con opciones: $e1 | sin opciones: $e';
    }
  }

  try {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    LoggerService.instance.error('Firebase background handler error', e);
  }

  // ApiClient primero: otros servicios pueden necesitar el token.
  try {
    await ApiClient.instance.init();
  } catch (e) {
    LoggerService.instance.error('ApiClient init error', e);
  }

  // CacheService (Hive) — AWAITED antes de cualquier lectura de caché.
  try {
    await CacheService.instance.init();
  } catch (e) {
    LoggerService.instance.error('CacheService init error', e);
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

  // No bloquean el arranque — se lanzan en paralelo al final.
  unawaited(
    NotificationService.instance.init().catchError((e, s) {
      LoggerService.instance.error('NotificationService init error', e, s);
    }),
  );

  unawaited(
    SocketServiceClient.instance.init().catchError((e, s) {
      LoggerService.instance.error('SocketServiceClient init error', e, s);
    }),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Recuperación de sesión — sólo lectura, CacheService ya está abierto.
// ─────────────────────────────────────────────────────────────────────────────
void _recoverSession() {
  final token = ApiClient.instance.token;
  if (token == null) return;

  LoggerService.instance
      .info('Session recovered for user: ${ApiClient.instance.userId}');
  AnalyticsService.instance
      .setUserId(ApiClient.instance.userId ?? 'unknown');
  AnalyticsService.instance.logEvent('session_recovered');

  final cachedTrip = CacheService.instance.getCachedActiveTrip();
  if (cachedTrip != null) {
    LoggerService.instance
        .info('Cached active trip found: ${cachedTrip['id']}');
  }
}

Future<void> _loadConfig() => MapConfig.ensureLoaded();

// ─────────────────────────────────────────────────────────────────────────────
// App widget
// ─────────────────────────────────────────────────────────────────────────────
class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      title: 'CargaExpress',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.black),
        useMaterial3: true,
      ),
      home: ApiClient.instance.token != null
          ? _homeScreenByRole()
          : const AuthScreen(),
    );
  }
}