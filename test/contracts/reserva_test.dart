import 'package:flutter_test/flutter_test.dart';

import 'package:cargaexpress/contracts/solicitud.dart';
import 'package:cargaexpress/contracts/trip_status.dart';

void main() {
  test('una reserva sin conductor sigue abierta a ofertas', () {
    expect(solicitudSigueAbierta('reservado'), isTrue);
    expect(solicitudSigueAbierta('buscando_conductor'), isTrue);
    expect(solicitudSigueAbierta('aceptado'), isFalse);
    expect(solicitudSigueAbierta('cancelado'), isFalse);
  });

  test('esReservaProgramada: por tipoProgramacion o por estado', () {
    expect(esReservaProgramada({'tipoProgramacion': 'programada'}), isTrue);
    expect(esReservaProgramada({'estado': 'reservado'}), isTrue);
    expect(esReservaProgramada({'estado': 'buscando_conductor'}), isFalse);
  });

  test('el chat de una reserva solo se habilita con conductor asignado', () {
    expect(TripStatus.chatHabilitado('reservado'), isFalse);
    expect(TripStatus.chatHabilitado('reservado', conConductor: true), isTrue);
    expect(TripStatus.chatHabilitado('aceptado'), isTrue);
    expect(TripStatus.chatHabilitado('finalizado', conConductor: true), isFalse);
    expect(TripStatus.chatHabilitadoEn({'estado': 'reservado'}), isFalse);
    expect(TripStatus.chatHabilitadoEn({'estado': 'reservado', 'conductor': {'nombre': 'Ana'}}), isTrue);
  });

  test('esReservaAsignada: reservado y con conductor', () {
    expect(TripStatus.esReservaAsignada({'estado': 'reservado', 'conductor': {'id': 1}}), isTrue);
    expect(TripStatus.esReservaAsignada({'estado': 'reservado'}), isFalse);
    expect(TripStatus.esReservaAsignada({'estado': 'aceptado', 'conductor': {'id': 1}}), isFalse);
    expect(TripStatus.esReservaAsignada(null), isFalse);
  });
}
