import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:cargaexpress/screens/cliente/home_screen.dart';

import '../../helpers/fake_api.dart';

const _reserva = {
  '_id': 't1',
  'estado': 'reservado',
  'tipoProgramacion': 'programada',
  'origen': {'direccion': 'Calle 1'},
  'destino': {'direccion': 'Calle 2'},
  'precioFinal': 30000,
  'conductor': {'_id': 'c1', 'nombre': 'Carlos', 'placa': 'ABC123'},
  'plazoSolicitud': {'minutos': 30, 'estado': 'pendiente'},
};

void main() {
  testWidgets('el conductor pidió más tiempo: el inicio muestra el diálogo y acepta', (tester) async {
    pantallaAlta(tester);
    final log = <http.Request>[];
    await conApiFalsa((req) {
      if (req.url.path == '/api/trips/active') return jsonResp(_reserva);
      return jsonResp({'data': []});
    }, () async {
      await tester.pumpWidget(const MaterialApp(home: ClienteHomeScreen()));
      await avanzar(tester, 2);
      expect(find.text('El conductor pide 30 min más'), findsOneWidget);

      await tester.tap(find.text('Aceptar'));
      await avanzar(tester);

      final post = log.firstWhere((r) => r.url.path == '/api/trips/t1/plazo/responder');
      expect(jsonDecode(post.body), {'aceptar': true});
    }, log: log);
  });

  testWidgets('rechazar el plazo manda aceptar:false', (tester) async {
    pantallaAlta(tester);
    final log = <http.Request>[];
    await conApiFalsa((req) {
      if (req.url.path == '/api/trips/active') return jsonResp(_reserva);
      return jsonResp({'data': []});
    }, () async {
      await tester.pumpWidget(const MaterialApp(home: ClienteHomeScreen()));
      await avanzar(tester, 2);
      await tester.tap(find.text('Rechazar'));
      await avanzar(tester);

      final post = log.firstWhere((r) => r.url.path == '/api/trips/t1/plazo/responder');
      expect(jsonDecode(post.body), {'aceptar': false});
    }, log: log);
  });
}
