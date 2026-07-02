import 'package:flutter_driver/flutter_driver.dart';
import 'package:test/test.dart';

void main() {
  group('CargaExpress App', () {
    late FlutterDriver driver;

    setUpAll(() async {
      driver = await FlutterDriver.connect();
    });

    tearDownAll(() async {
      driver.close();
    });

    test('app smoke test', () async {
      final result = await driver.checkHealth();
      expect(result.status, HealthStatus.ok);
    });
  });
}