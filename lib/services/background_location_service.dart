import 'dart:async';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:geolocator/geolocator.dart';
import 'api/driver_service.dart';
import 'logger_service.dart';

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
          isForegroundMode: true,
          notificationChannelId: 'location_service',
          initialNotificationTitle: 'CargaExpress',
          initialNotificationContent: 'Enviando ubicaci\u00f3n en segundo plano',
          foregroundServiceNotificationId: 888,
        ),
      );
    } catch (e) {
      LoggerService.instance.error('BackgroundLocationService.initialize error', e);
    }
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) {
    if (service is AndroidServiceInstance) {
      service.on('stopService').listen((_) {
        service.stopSelf();
      });
    }

    Timer.periodic(const Duration(seconds: 15), (timer) async {
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        );
        await DriverService.updateLocation(pos.latitude, pos.longitude);
      } catch (e) {
        LoggerService.instance.error('BackgroundLocationService.onStart location error', e);
      }
    });
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    return true;
  }

  Future<void> start() async {
    if (_isRunning) return;
    _isRunning = true;
    try {
      final service = FlutterBackgroundService();
      service.startService();
    } catch (e) {
      LoggerService.instance.error('BackgroundLocationService.start error', e);
    }
  }

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
