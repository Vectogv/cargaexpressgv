import 'package:flutter_test/flutter_test.dart';

import 'package:cargaexpress/contracts/cancelacion.dart';

void main() {
  group('mensajeViajeCancelado', () {
    test('el cliente que canceló no recibe un segundo aviso', () {
      expect(mensajeViajeCancelado({'canceladoPor': 'cliente'}, miRol: 'cliente'), isNull);
    });

    test('el conductor que canceló no ve "cancelado por el cliente"', () {
      expect(mensajeViajeCancelado({'canceladoPor': 'conductor'}, miRol: 'conductor'), isNull);
    });

    test('cliente ve que canceló el conductor, con motivo', () {
      expect(
        mensajeViajeCancelado({'canceladoPor': 'conductor', 'motivo': 'Vehículo averiado'}, miRol: 'cliente'),
        'El conductor canceló el viaje: Vehículo averiado',
      );
      expect(mensajeViajeCancelado({'canceladoPor': 'conductor'}, miRol: 'cliente'),
          'El conductor canceló el viaje');
    });

    test('conductor ve que canceló el cliente', () {
      expect(mensajeViajeCancelado({'canceladoPor': 'cliente', 'motivo': ''}, miRol: 'conductor'),
          'El cliente canceló el viaje');
    });

    test('soporte y payload antiguo sin canceladoPor', () {
      expect(mensajeViajeCancelado({'canceladoPor': 'admin', 'motivo': 'x'}, miRol: 'cliente'),
          'El viaje fue cancelado por soporte');
      expect(mensajeViajeCancelado({'id': '1'}, miRol: 'cliente'), 'El viaje fue cancelado');
      expect(mensajeViajeCancelado({'id': '1'}, miRol: null), 'El viaje fue cancelado');
    });
  });
}
