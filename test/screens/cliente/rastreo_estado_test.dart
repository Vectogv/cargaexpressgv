import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cargaexpress/contracts/trip_status.dart';
import 'package:cargaexpress/screens/cliente/rastreo_screen.dart';
import 'package:cargaexpress/screens/cliente/rastreo_ui.dart';

import '../../helpers/fake_api.dart';

void main() {
  group('formatoFechaHoraReserva', () {
    test('formatea fecha y hora del backend', () {
      expect(formatoFechaHoraReserva('2026-09-26', '18:03'), '26 sep, 6:03 p. m.');
      expect(formatoFechaHoraReserva('2026-01-05', '08:00'), '5 ene, 8:00 a. m.');
      expect(formatoFechaHoraReserva('2026-01-05', '00:15'), '5 ene, 12:15 a. m.');
    });

    test('null si falta fecha u hora', () {
      expect(formatoFechaHoraReserva(null, '18:03'), isNull);
      expect(formatoFechaHoraReserva('2026-09-26', null), isNull);
    });
  });

  testWidgets('reserva sin activar: la pantalla muestra la hora, el origen y el destino que se ingresaron', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa((req) {
      if (req.url.path == '/api/trips/active') {
        return jsonResp({
          '_id': 't1',
          'estado': 'reservado',
          'tipoProgramacion': 'programada',
          'fechaProgramada': '2026-09-26',
          'horaProgramada': '18:03',
          'origen': {'lat': 4.6, 'lng': -74.1, 'direccion': 'Parque Caldas'},
          'destino': {'lat': 4.7, 'lng': -74.2, 'direccion': 'Campanario'},
          'precioEstimado': 90000,
        });
      }
      return jsonResp([]);
    }, () async {
      await tester.pumpWidget(const MaterialApp(home: RastreoScreen()));
      await avanzar(tester);
      // Aparece en la barra superior y en el título de la pantalla.
      expect(find.text('Reserva programada'), findsNWidgets(2));
      expect(find.text('26 sep, 6:03 p. m.'), findsOneWidget);
      expect(find.text('Parque Caldas'), findsOneWidget);
      expect(find.text('Campanario'), findsOneWidget);
      expect(find.text('\$90.000 COP'), findsOneWidget);
    });
  });

  test('chat del viaje disponible en los mismos estados que chat_controller.ts', () {
    for (final e in [
      TripStatus.aceptado,
      TripStatus.enCurso,
      TripStatus.enCamino,
      TripStatus.llegada,
      TripStatus.sos,
    ]) {
      expect(TripStatus.chatHabilitado(e), isTrue, reason: e);
    }
    for (final e in [TripStatus.buscando, TripStatus.pendienteConfirmacion, TripStatus.finalizado, null]) {
      expect(TripStatus.chatHabilitado(e), isFalse, reason: e);
    }
  });

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

  testWidgets(
      'RastreoEstadoInfo con acción primaria muestra "Intentar de nuevo" en vez de soporte',
      (tester) async {
    var reintentar = 0;
    var inicio = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RastreoEstadoInfo(
          icon: Icons.search_off_rounded,
          color: Colors.red,
          titulo: 'No encontramos conductor',
          mensaje: 'Pasaron 15 minutos sin que un conductor aceptara tu envío, '
              'así que lo cancelamos. No se te cobró nada. Puedes intentarlo de nuevo.',
          accionPrimariaTexto: 'Intentar de nuevo',
          accionPrimariaIcon: Icons.refresh_rounded,
          onAccionPrimaria: () => reintentar++,
          onInicio: () => inicio++,
        ),
      ),
    ));

    expect(find.text('No encontramos conductor'), findsOneWidget);
    expect(find.text('Intentar de nuevo'), findsOneWidget);
    expect(find.text('Contactar a soporte'), findsNothing);

    await tester.tap(find.text('Intentar de nuevo'));
    await tester.tap(find.text('Volver al inicio'));
    expect(reintentar, 1);
    expect(inicio, 1);
  });
}
