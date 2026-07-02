class Environment {
  Environment._();

  static const bool testMode = bool.fromEnvironment('TEST_MODE', defaultValue: false);

  static const bool isEmulator = bool.fromEnvironment('EMULATOR', defaultValue: false);

  static String get baseUrl {
    if (testMode) {
      return 'http://10.0.2.2:3333';
    }
    return 'http://localhost:3333';
  }

  static String get wsUrl {
    if (testMode) {
      return 'http://10.0.2.2:3333';
    }
    return 'http://localhost:3333';
  }

  static String get apiBaseUrl => '$baseUrl/api';
}
