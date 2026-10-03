import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:cargaexpress/screens/cliente/viaje_detalle_screen.dart';

import '../../helpers/fake_api.dart';

// Forma real del servidor (formatViajeResponse): el pedido viaja en `plazo`.
const _reserva = {
  '_id': 't1',
  'estado': 'reservado',
  'tipoProgramacion': 'programada',
  'origen': {'direccion': 'Calle 1'},
  'destino': {'direccion': 'Calle 2'},
  'precioFinal': 30000,
  'conductor': {'_id': 'c1', 'nombre': 'Carlos', 'placa': 'ABC123'},
  'plazo': {'minutos': 30, 'estado': 'pendiente'},
};

Future<void> _responder(WidgetTester tester, String boton, bool esperado) async {
  pantallaAlta(tester);
  final log = <http.Request>[];
  await conApiFalsa((req) {
    if (req.url.path.endsWith('/offers')) return jsonResp([]);
    if (req.url.path.endsWith('/plazo/responder')) return jsonResp({'id': 't1'});
    // Ya respondido: la relectura no vuelve a mostrar el diálogo.
    final respondido = log.any((r) => r.url.path.endsWith('/plazo/responder'));
    return jsonResp(respondido ? {..._reserva, 'plazo': {'minutos': 30, 'estado': 'aceptado'}} : _reserva);
  }, () async {
    await tester.pumpWidget(const MaterialApp(home: ViajeDetalleScreen(tripId: 't1')));
    await avanzar(tester, 2);
    expect(find.text('El conductor pide 30 min más'), findsOneWidget);

    await tester.tap(find.text(boton));
    await avanzar(tester);

    final post = log.firstWhere((r) => r.url.path == '/api/trips/t1/plazo/responder');
    expect(jsonDecode(post.body), {'aceptar': esperado});
    expect(find.text('El conductor pide 30 min más'), findsNothing);
  }, log: log);
}

void main() {
  testWidgets('el conductor pidió más tiempo: el detalle de la reserva lo muestra y acepta',
      (tester) => _responder(tester, 'Aceptar', true));

  testWidgets('rechazar el plazo manda aceptar:false', (tester) => _responder(tester, 'Rechazar', false));
}
