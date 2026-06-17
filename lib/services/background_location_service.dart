import 'dart:async';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:geolocator/geolocator.dart';
import 'api/driver_service.dart';

class BackgroundLocationService {
  static final BackgroundLocationService instance = BackgroundLocationService._();
  BackgroundLocationService._();

  bool _isRunning = false;

  Future<void> initialize() async {
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
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) {
    if (service is AndroidServiceInstance) {
      service.on('stopService');
    }

    Timer.periodic(const Duration(seconds: 15), (timer) async {
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        );
        await DriverService.updateLocation(pos.latitude, pos.longitude);
      } catch (_) {}
    });
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    return true;
  }

  Future<void> start() async {
    if (_isRunning) return;
    _isRunning = true;
    final service = FlutterBackgroundService();
    service.startService();
  }

  Future<void> stop() async {
    _isRunning = false;
    final service = FlutterBackgroundService();
    service.invoke('stopService');
  }
}
