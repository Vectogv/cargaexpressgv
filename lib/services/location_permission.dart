import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Motivo por el que no se pudo obtener la ubicación.
enum LocationIssue { serviceDisabled, denied, deniedForever, unavailable }

/// Error de ubicación con un mensaje listo para mostrar al usuario.
class LocationException implements Exception {
  final LocationIssue issue;
  final String message;
  const LocationException(this.issue, this.message);

  @override
  String toString() => message;
}

/// Acceso a la plataforma de ubicación. Se puede reemplazar en pruebas.
class LocationSource {
  const LocationSource();

  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();
  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();
  Future<LocationPermission> requestPermission() => Geolocator.requestPermission();
  Future<Position> current(LocationAccuracy accuracy, Duration timeLimit) =>
      Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(accuracy: accuracy, timeLimit: timeLimit),
      );
  Future<Position?> lastKnown() => Geolocator.getLastKnownPosition();
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
  Future<bool> openAppSettings() => Geolocator.openAppSettings();
}

/// Garantiza que el GPS esté activo y que la app tenga permiso de ubicación
/// antes de pedir la posición (Geolocator no lo pide por sí solo), y obtiene
/// la posición sin quedarse colgado: sin señal GPS (interiores) o sin
/// ubicación por red, `getCurrentPosition` sin `timeLimit` nunca termina.
class LocationPermissionHelper {
  @visibleForTesting
  static LocationSource source = const LocationSource();

  static const String msgServiceDisabled =
      'La ubicación (GPS) del teléfono está desactivada.';
  static const String msgDenied = 'Necesitamos permiso de ubicación para continuar.';
  static const String msgDeniedForever =
      'El permiso de ubicación está bloqueado. Actívalo en Ajustes > Permisos > Ubicación.';
  static const String msgUnavailable =
      'No pudimos obtener tu ubicación. Revisa la señal o elige el punto manualmente.';

  /// Verifica servicio y permiso (pidiéndolo si hace falta).
  /// Con [openSettings] abre los ajustes del sistema cuando el usuario no
  /// puede resolverlo desde el diálogo de permisos.
  /// Lanza [LocationException] si no hay acceso a la ubicación.
  static Future<void> ensure({bool openSettings = true}) async {
    if (!await source.isServiceEnabled()) {
      if (openSettings) await source.openLocationSettings();
      throw const LocationException(LocationIssue.serviceDisabled, msgServiceDisabled);
    }

    var permission = await source.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await source.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const LocationException(LocationIssue.denied, msgDenied);
    }
    if (permission == LocationPermission.deniedForever) {
      if (openSettings) await source.openAppSettings();
      throw const LocationException(LocationIssue.deniedForever, msgDeniedForever);
    }
  }

  /// Posición actual con límite de tiempo y alternativas:
  /// 1. alta precisión durante [timeLimit];
  /// 2. última posición conocida, si [allowLastKnown];
  /// 3. precisión media durante [fallbackLimit] (ubicación por red/wifi).
  /// Siempre termina: devuelve una posición o lanza [LocationException].
  /// No verifica permisos: llamar antes a [ensure].
  static Future<Position> currentPosition({
    Duration timeLimit = const Duration(seconds: 10),
    Duration fallbackLimit = const Duration(seconds: 6),
    bool allowLastKnown = true,
  }) async {
    final high = await _tryCurrent(LocationAccuracy.high, timeLimit);
    if (high != null) return high;

    if (allowLastKnown) {
      try {
        final last = await source.lastKnown().timeout(const Duration(seconds: 3));
        if (last != null) return last;
      } catch (_) {}
    }

    final medium = await _tryCurrent(LocationAccuracy.medium, fallbackLimit);
    if (medium != null) return medium;

    throw const LocationException(LocationIssue.unavailable, msgUnavailable);
  }

  static Future<Position?> _tryCurrent(LocationAccuracy accuracy, Duration limit) async {
    try {
      // Doble límite: el timeLimit del plugin y un timeout propio por si el
      // plugin no llega a responder.
      return await source
          .current(accuracy, limit)
          .timeout(limit + const Duration(seconds: 1));
    } on LocationServiceDisabledException {
      throw const LocationException(LocationIssue.serviceDisabled, msgServiceDisabled);
    } on PermissionDeniedException {
      throw const LocationException(LocationIssue.denied, msgDenied);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> openLocationSettings() => source.openLocationSettings();
  static Future<bool> openAppSettings() => source.openAppSettings();
}
