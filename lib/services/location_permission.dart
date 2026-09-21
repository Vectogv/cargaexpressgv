import 'package:geolocator/geolocator.dart';

/// Garantiza que el GPS esté activo y que la app tenga permiso de ubicación
/// antes de llamar a Geolocator.getCurrentPosition (que no lo pide por sí solo).
class LocationPermissionHelper {
  static Future<void> ensure() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      await Geolocator.openLocationSettings();
      throw Exception('Activa la ubicación (GPS) del teléfono e inténtalo de nuevo');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw Exception('Necesitamos permiso de ubicación para continuar');
    }
    if (permission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      throw Exception('El permiso de ubicación está bloqueado. Actívalo en Ajustes > Permisos > Ubicación');
    }
  }
}
