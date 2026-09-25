import 'package:flutter_test/flutter_test.dart';

import 'package:cargaexpress/services/api/payment_service.dart';

/// Misma regla que POST /api/payment/proof del backend.
void main() {
  test('con deuda se puede subir en cualquier estado salvo en revisión', () {
    expect(puedeSubirComprobante({'estadoCuenta': 'activa', 'montoDeuda': 15000}), isTrue);
    expect(puedeSubirComprobante({'estadoCuenta': 'suspension_por_pago', 'montoDeuda': '15000.00'}), isTrue);
    expect(puedeSubirComprobante({'estadoCuenta': 'esperando_confirmacion', 'montoDeuda': 15000}), isFalse);
  });

  test('sin deuda o sin datos no se puede', () {
    expect(puedeSubirComprobante(null), isFalse);
    expect(puedeSubirComprobante({'estadoCuenta': 'activa', 'montoDeuda': 0}), isFalse);
    expect(puedeSubirComprobante({'estadoCuenta': 'suspension_por_pago', 'montoDeuda': null}), isFalse);
  });
}
