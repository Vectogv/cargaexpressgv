import 'dart:async';
import 'dart:ui' show DartPluginRegistrant;
import 'package:flutter/widgets.dart' show AppLifecycleState, WidgetsBinding;
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'api/driver_service.dart';
import 'api/http_client.dart';
import 'api_client.dart';
import 'logger_service.dart';

// En release (AOT) el servicio nativo llama a [onStart] por reflexión: la
// clase también debe estar anotada o el isolate no arranca y Android cierra
// la app (ForegroundServiceDidNotStartInTimeException).
@pragma('vm:entry-point')
class BackgroundLocationService {
  static final BackgroundLocationService instance = BackgroundLocationService._();
  BackgroundLocationService._();

  bool _isRunning = false;

  Future<void> initialize() async {
    try {
      final service = FlutterBackgroundService();

      await service.configure(
        iosConfiguration: IosConfiguration(
          autoStart: false,
          onForeground: onStart,
          onBackground: onIosBackground,
        ),
        androidConfiguration: AndroidConfiguration(
          onStart: onStart,
          autoStart: false,
          // Sólo arranca cuando el conductor se conecta con la app abierta:
          // tras reiniciar el teléfono no hay permiso para iniciarlo.
          autoStartOnBoot: false,
          isForegroundMode: true,
          notificationChannelId: 'location_service',
          initialNotificationTitle: 'CargaExpress',
          initialNotificationContent: 'Enviando ubicaci\u00f3n en segundo plano',
          foregroundServiceNotificationId: 888,
          // Android 14+ exige el tipo del servicio en primer plano (debe
          // coincidir con android:foregroundServiceType del manifiesto).
          foregroundServiceTypes: [AndroidForegroundType.location],
        ),
      );
    } catch (e) {
      LoggerService.instance.error('BackgroundLocationService.initialize error', e);
    }
  }

  /// Punto de entrada del isolate del servicio en segundo plano. Este isolate
  /// NO comparte memoria con la app: hay que registrar los plugins y cargar la
  /// sesión desde SharedPreferences. Nunca renueva tokens (los refresh tokens
  /// son de un solo uso y los rota el isolate principal): ante 401 HttpClient
  /// relee los tokens y reintenta una vez.
  @pragma('vm:entry-point')
  static Future<void> onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();
    HttpClient.isBackgroundIsolate = true;
    try {
      await ApiClient.instance.init();
    } catch (e) {
      LoggerService.instance.error('BackgroundLocationService: ApiClient init error', e);
    }

    Timer? timer;
    service.on('stopService').listen((_) {
      timer?.cancel();
      service.stopSelf();
    });

    if (service is AndroidServiceInstance) {
      service.on('setForegroundText').listen((event) {
        final title = event?['title']?.toString() ?? 'CargaExpress';
        final content = event?['content']?.toString() ??
            'Enviando ubicación en segundo plano';
        service.setForegroundNotificationInfo(title: title, content: content);
      });
    }

    var busy = false;
    timer = Timer.periodic(const Duration(seconds: 15), (_) async {
      if (busy) return;
      busy = true;
      try {
        if (ApiClient.instance.token == null) {
          // El usuario pudo iniciar sesión (o renovar) en la app principal.
          await ApiClient.instance.reloadTokens();
          if (ApiClient.instance.token == null) return;
        }
        final pos = await Geolocator.getCurrentPosition(
          // Con límite: sin señal GPS la llamada nunca terminaría.
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)),
        );
        await DriverService.updateLocation(pos.latitude, pos.longitude);
      } on ApiException catch (e) {
        if (e.code == 'CUENTA_SUSPENDIDA') {
          LoggerService.instance.warning('BackgroundLocationService: cuenta suspendida, deteniendo');
          timer?.cancel();
          service.stopSelf();
        } else {
          LoggerService.instance.error('BackgroundLocationService.onStart api error', e);
        }
      } catch (e) {
        LoggerService.instance.error('BackgroundLocationService.onStart location error', e);
      } finally {
        busy = false;
      }
    });
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    return true;
  }

  /// Inicia el servicio sólo con la app en pantalla: Android 14+ no permite
  /// arrancar un servicio de ubicación desde segundo plano sin el permiso
  /// "todo el tiempo" y, si se intenta, cierra la app.
  Future<void> start() async {
    if (_isRunning) return;
    final estado = WidgetsBinding.instance.lifecycleState;
    if (estado == AppLifecycleState.paused || estado == AppLifecycleState.hidden) {
      LoggerService.instance.warning('BackgroundLocationService: app en segundo plano, no se inicia el servicio');
      return;
    }
    _isRunning = true;
    try {
      final service = FlutterBackgroundService();
      await service.startService();
    } catch (e) {
      _isRunning = false;
      LoggerService.instance.error('BackgroundLocationService.start error', e);
    }
  }

  /// Detiene el servicio (y con él la alarma "watchdog" del plugin) al
  /// desconectarse o cerrar sesión: sin esto seguía enviando ubicación.
  Future<void> stop() async {
    _isRunning = false;
    try {
      final service = FlutterBackgroundService();
      service.invoke('stopService');
    } catch (e) {
      LoggerService.instance.error('BackgroundLocationService.stop error', e);
    }
  }

  Future<void> updateNotification({String? estado, String? destino}) async {
    try {
      final service = FlutterBackgroundService();
      service.invoke('setForegroundText', {
        'title': estado != null ? 'Viaje $estado' : 'CargaExpress',
        'content': destino != null ? 'Destino: $destino' : 'Enviando ubicaci\u00f3n en segundo plano',
      });
    } catch (e) {
      LoggerService.instance.error('BackgroundLocationService.updateNotification error', e);
    }
  }
}
