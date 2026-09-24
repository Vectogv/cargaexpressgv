import 'package:flutter_test/flutter_test.dart';

import 'package:cargaexpress/contracts/cancelacion.dart';
import 'package:cargaexpress/contracts/trip_status.dart';

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

    test('sin conductor tras BUSQUEDA_TIMEOUT_MIN: aviso honesto, no genérico', () {
      final msg = mensajeViajeCancelado(
        {'canceladoPor': 'sistema', 'motivo': motivoCancelacionSistema},
        miRol: 'cliente',
      );
      expect(msg, contains('15 minutos'));
      expect(msg, contains('No se te cobró nada'));
      expect(msg, isNot(contains('El viaje fue cancelado')));
    });

    test('payload viejo sin canceladoPor pero con el motivo del sistema también es honesto', () {
      final msg = mensajeViajeCancelado({'motivo': motivoCancelacionSistema}, miRol: 'cliente');
      expect(msg, contains('15 minutos'));
    });
  });

  group('esCanceladoPorSistema', () {
    test('canceladoPor "sistema" del payload en vivo', () {
      expect(esCanceladoPorSistema(canceladoPor: 'sistema'), isTrue);
    });

    test('motivoCancelacion persistido al recargar (sin canceladoPor)', () {
      expect(esCanceladoPorSistema(motivo: motivoCancelacionSistema), isTrue);
    });

    test('cancelación normal del cliente/conductor/admin no es del sistema', () {
      expect(esCanceladoPorSistema(canceladoPor: 'cliente', motivo: 'Cambié de opinión'), isFalse);
      expect(esCanceladoPorSistema(canceladoPor: 'admin'), isFalse);
      expect(esCanceladoPorSistema(motivo: 'Cancelado por el conductor'), isFalse);
      expect(esCanceladoPorSistema(), isFalse);
    });
  });

  group('minutosBusquedaDesde', () {
    test('usa el valor del payload si viene', () {
      expect(minutosBusquedaDesde({'busquedaTimeoutMin': 20}), 20);
      expect(minutosBusquedaDesde({'timeoutMin': '10'}), 10);
      expect(minutosBusquedaDesde({'minutos': 5}), 5);
    });

    test('sin valor en el payload, 15 por defecto (BUSQUEDA_TIMEOUT_MIN)', () {
      expect(minutosBusquedaDesde({}), 15);
      expect(minutosBusquedaDesde({'id': '1'}), busquedaTimeoutMinPorDefecto);
    });
  });

  group('etiquetaCancelacion', () {
    test('motivo del sistema: etiqueta específica', () {
      expect(etiquetaCancelacion(motivoCancelacionSistema), 'Cancelado: sin conductor disponible');
    });

    test('cualquier otro motivo (o ninguno): etiqueta genérica', () {
      expect(etiquetaCancelacion('Cambié de opinión'), 'Cancelado');
      expect(etiquetaCancelacion(null), 'Cancelado');
      expect(etiquetaCancelacion('Cancelado por el conductor'), 'Cancelado');
    });
  });

  group('cancelacionRequiereSolicitud', () {
    test('en_curso y conductor_llegada requieren solicitud (motivos "en curso")', () {
      expect(cancelacionRequiereSolicitud(TripStatus.enCurso), isTrue);
      expect(cancelacionRequiereSolicitud(TripStatus.llegada), isTrue);
    });

    test('durante un SOS la cancelación también va por solicitud (revisión del admin)', () {
      expect(cancelacionRequiereSolicitud(TripStatus.sos), isTrue);
    });

    test('antes de la llegada se cancela directo', () {
      expect(cancelacionRequiereSolicitud(TripStatus.buscando), isFalse);
      expect(cancelacionRequiereSolicitud(TripStatus.aceptado), isFalse);
      expect(cancelacionRequiereSolicitud(TripStatus.enCamino), isFalse);
    });
  });
}
