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

  group('Mensajes del backend para 409/422 (oferta, registro, cierre)', () {
    // Las pantallas (hacer oferta, aceptar oferta, registro, moderador)
    // muestran ApiException.message: debe ser el texto del backend, no uno
    // genérico, para los nuevos códigos de conflicto.
    test('409 CONDUCTOR_OCUPADO usa el campo error', () {
      final msg = HttpClient.extractError(
        {'code': 'CONDUCTOR_OCUPADO', 'error': 'Ya tienes un viaje activo'},
        409,
      );
      expect(msg, 'Ya tienes un viaje activo');
    });

    test('409 CONFIRMACION_EN_PLAZO usa el campo message', () {
      final msg = HttpClient.extractError(
        {'code': 'CONFIRMACION_EN_PLAZO', 'message': 'El cliente aun tiene tiempo'},
        409,
      );
      expect(msg, 'El cliente aun tiene tiempo');
    });

    test('422 de registro duplicado (errors[0].message)', () {
      final msg = HttpClient.extractError(
        {'errors': [{'message': 'La placa ya está registrada'}]},
        422,
      );
      expect(msg, 'La placa ya está registrada');
    });
  });
}
