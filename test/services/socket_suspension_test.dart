import 'package:flutter_test/flutter_test.dart';

import 'package:cargaexpress/services/socket_service_client.dart';

void main() {
  test('sólo CUENTA_SUSPENDIDA exacto es suspensión de la cuenta (cierra sesión)', () {
    expect(SocketServiceClient.isSuspendedError({'data': {'code': 'CUENTA_SUSPENDIDA'}}), isTrue);
    expect(SocketServiceClient.isSuspendedError({'message': 'Cuenta suspendida'}), isTrue);
    expect(SocketServiceClient.isSuspendedError('Error: CUENTA_SUSPENDIDA'), isTrue);
  });

  test('la suspensión por pago no se confunde con la suspensión de la cuenta', () {
    expect(SocketServiceClient.isSuspendedError({'data': {'code': 'CUENTA_SUSPENDIDA_POR_PAGO'}}), isFalse);
    expect(SocketServiceClient.isSuspendedError({'code': 'CUENTA_SUSPENDIDA_POR_PAGO', 'message': 'Cuenta suspendida por pago'}), isFalse);
    expect(SocketServiceClient.isSuspendedError('code: CUENTA_SUSPENDIDA_POR_PAGO'), isFalse);
  });
}
