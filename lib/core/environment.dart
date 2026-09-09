import 'package:flutter/foundation.dart' show visibleForTesting;

class Environment {
  Environment._();

  static const bool testMode = bool.fromEnvironment('TEST_MODE', defaultValue: false);

  static const bool isEmulator = bool.fromEnvironment('EMULATOR', defaultValue: false);

  /// Override con --dart-define=PRODUCTION_URL=https://bakend-cargaexpress-production.up.railway.app
  static const String _customUrl = String.fromEnvironment('PRODUCTION_URL', defaultValue: '');

  static String? _testOverride;

  /// Permite a tests unitarios apuntar a un servidor embebido.
  @visibleForTesting
  static set testBaseUrl(String? url) => _testOverride = url;

  static String get baseUrl {
    if (_testOverride != null) return _testOverride!;
    if (_customUrl.isNotEmpty) return _customUrl;
    if (testMode) return 'http://10.0.2.2:3333';
    return 'https://bakend-cargaexpress-production.up.railway.app';
  }

  static String get wsUrl => baseUrl;

  static String get apiBaseUrl => '$baseUrl/api';
}
