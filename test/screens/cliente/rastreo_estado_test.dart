import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cargaexpress/contracts/trip_status.dart';
import 'package:cargaexpress/screens/cliente/rastreo_screen.dart';

void main() {
  group('rastreoVistaPara', () {
    test('disputa y en_disputa no muestran la búsqueda de conductor', () {
      expect(rastreoVistaPara(TripStatus.disputa), RastreoVista.disputa);
      expect(rastreoVistaPara(TripStatus.enDisputa), RastreoVista.disputa);
    });

    test('estados terminales y desconocidos no caen en la búsqueda', () {
      expect(rastreoVistaPara(TripStatus.cancelado), RastreoVista.cerrado);
      expect(rastreoVistaPara(TripStatus.rechazado), RastreoVista.cerrado);
      expect(rastreoVistaPara(TripStatus.reservado), RastreoVista.reserva);
      expect(rastreoVistaPara('estado_nuevo'), isNot(RastreoVista.busqueda));
    });

    test('mapea todos los estados del backend', () {
      expect(rastreoVistaPara(TripStatus.buscando), RastreoVista.busqueda);
      expect(rastreoVistaPara(TripStatus.pendiente), RastreoVista.busqueda);
      expect(rastreoVistaPara(TripStatus.sos), RastreoVista.seguimiento);
      expect(rastreoVistaPara(TripStatus.enCurso), RastreoVista.seguimiento);
      expect(rastreoVistaPara(TripStatus.pendienteConfirmacion), RastreoVista.entrega);
      expect(rastreoVistaPara(TripStatus.finalizado), RastreoVista.entrega);
    });
  });

  group('TripStatus.label', () {
    test('pendiente_confirmacion y disputa tienen texto legible', () {
      expect(TripStatus.label('pendiente_confirmacion'), isNot('pendiente_confirmacion'));
      expect(TripStatus.label('disputa'), 'En disputa');
      expect(TripStatus.label(null), '');
    });
  });

  testWidgets('RastreoEstadoInfo muestra disputa con soporte y volver al inicio',
      (tester) async {
    var soporte = 0;
    var inicio = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RastreoEstadoInfo(
          icon: Icons.gavel_rounded,
          color: Colors.orange,
          titulo: 'Viaje en disputa',
          mensaje: 'Un moderador está revisando el caso.',
          onSoporte: () => soporte++,
          onInicio: () => inicio++,
        ),
      ),
    ));

    expect(find.text('Viaje en disputa'), findsOneWidget);
    expect(find.textContaining('Buscando'), findsNothing);
    await tester.tap(find.text('Contactar a soporte'));
    await tester.tap(find.text('Volver al inicio'));
    expect(soporte, 1);
    expect(inicio, 1);
  });
}
