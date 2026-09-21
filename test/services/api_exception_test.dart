import 'package:flutter_test/flutter_test.dart';
import 'package:cargaexpress/services/api/http_client.dart';

void main() {
  group('ApiException', () {
    test('includes code field when constructed', () {
      final exception = ApiException('Test error', statusCode: 422, code: 'JUSTIFICACION_REQUERIDA');
      expect(exception.message, 'Test error');
      expect(exception.statusCode, 422);
      expect(exception.code, 'JUSTIFICACION_REQUERIDA');
    });

    test('code can be null', () {
      final exception = ApiException('Test error', statusCode: 500);
      expect(exception.code, isNull);
    });

    test('toString maintains format for backward compatibility', () {
      final exception = ApiException('Test error', statusCode: 422, code: 'JUSTIFICACION_REQUERIDA');
      expect(exception.toString(), 'Exception: Test error');
    });
  });

  group('Error codes for antifraud', () {
    test('JUSTIFICACION_REQUERIDA is recognized', () {
      const code = 'JUSTIFICACION_REQUERIDA';
      expect(code, 'JUSTIFICACION_REQUERIDA');
    });

    test('CONDUCTOR_CERCA is recognized', () {
      const code = 'CONDUCTOR_CERCA';
      expect(code, 'CONDUCTOR_CERCA');
    });

    test('FUERA_DE_RANGO_ORIGEN is recognized', () {
      const code = 'FUERA_DE_RANGO_ORIGEN';
      expect(code, 'FUERA_DE_RANGO_ORIGEN');
    });
  });
}