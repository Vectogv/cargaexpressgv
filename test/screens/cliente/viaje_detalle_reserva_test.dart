import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:cargaexpress/screens/cliente/viaje_detalle_screen.dart';

import '../../helpers/fake_api.dart';

const _reserva = {
  'id': 'r1',
  'estado': 'reservado',
  'tipoProgramacion': 'programada',
  'fechaProgramada': '2026-10-05',
  'horaProgramada': '14:30',
  'origen': {'direccion': 'Calle 1'},
  'destino': {'direccion': 'Calle 2'},
  'precioEstimado': 80000,
  'createdAt': '2026-10-01T10:00:00.000Z',
};

const _oferta = {
  'id': 'o1',
  'monto': 85000,
  'conductor': {'nombre': 'Carlos', 'calificacion': 4.5, 'tipoVehiculo': 'camioneta', 'placa': 'PRB101'},
};

void main() {
  testWidgets('reserva sin conductor: lista las ofertas y acepta una', (tester) async {
    pantallaAlta(tester);
    final log = <http.Request>[];
    var asignada = false;
    await conApiFalsa((req) {
      final p = req.url.path;
      if (p.endsWith('/offers/o1/accept')) {
        asignada = true;
        return jsonResp({'message': 'ok'});
      }
      if (p.endsWith('/offers')) return jsonResp(asignada ? [] : [_oferta]);
      return jsonResp({..._reserva, if (asignada) 'conductor': _oferta['conductor']});
    }, () async {
      await tester.pumpWidget(const MaterialApp(home: ViajeDetalleScreen(tripId: 'r1')));
      await avanzar(tester);
      expect(find.text('Ofertas para tu reserva'), findsOneWidget);
      expect(find.text('Carlos'), findsOneWidget);
      expect(find.text('\$85.000'), findsOneWidget);
      expect(find.text('Cancelar reserva'), findsOneWidget);

      await tester.tap(find.byKey(const Key('reserva_aceptar_o1')));
      await avanzar(tester);
      expect(log.any((r) => r.method == 'POST' && r.url.path == '/api/trips/r1/offers/o1/accept'), isTrue);
      // Tras aceptar, se ve el conductor con chat y sin ofertas.
      expect(find.text('Ofertas para tu reserva'), findsNothing);
      expect(find.byKey(const Key('reserva_chat')), findsOneWidget);
      expect(find.text('Llamar'), findsNothing);
    }, log: log);
  });

  testWidgets('reserva con conductor: tarjeta con placa y chat, sin teléfono ni Llamar', (tester) async {
    pantallaAlta(tester);
    final conConductor = {..._reserva, 'conductor': {..._oferta['conductor'] as Map, 'telefono': '3001234567'}};
    await conApiFalsa((req) => req.url.path.endsWith('/offers') ? jsonResp([]) : jsonResp(conConductor), () async {
      await tester.pumpWidget(const MaterialApp(home: ViajeDetalleScreen(tripId: 'r1')));
      await avanzar(tester);
      expect(find.text('Reserva con conductor asignado'), findsOneWidget);
      expect(find.text('Carlos'), findsOneWidget);
      expect(find.text('PRB101'), findsOneWidget);
      expect(find.text('Verás su ubicación 45 min antes de la recogida.'), findsOneWidget);
      expect(find.byKey(const Key('reserva_chat')), findsOneWidget);
      expect(find.text('Cancelar reserva'), findsOneWidget);
      expect(find.text('Ofertas para tu reserva'), findsNothing);
      expect(find.text('Llamar'), findsNothing);
      expect(find.textContaining('3001234567'), findsNothing);
    });
  });
}
