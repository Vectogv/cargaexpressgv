import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cargaexpress/screens/conductor/hacer_oferta_screen.dart';
import 'package:cargaexpress/screens/conductor/offers_screen.dart';

import '../../helpers/fake_api.dart';

void main() {
  Future<void> ofertarCon(WidgetTester tester, int status, String error, [String? code]) async {
    pantallaAlta(tester);
    await conApiFalsa((req) => jsonResp({'error': error, if (code != null) 'code': code}, status), () async {
      await tester.pumpWidget(const MaterialApp(home: HacerOfertaScreen(tripId: 't1')));
      await tester.tap(find.text('Enviar oferta'));
      await avanzar(tester);
    });
  }

  const casos = {
    'FUERA_DE_ZONA': (422, 'Estás a 12.5 km del origen del viaje. Solo puedes ofertar a 10 km o menos.'),
    'CONDUCTOR_OCUPADO': (409, 'Ya estás atendiendo un servicio. Termínalo antes de ofertar en otro viaje.'),
    'CUENTA_SUSPENDIDA_POR_PAGO': (403, 'Tu cuenta está suspendida por pago pendiente.'),
  };

  testWidgets('Mis ofertas: pendiente_confirmacion se muestra legible, no crudo', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa((req) {
      if (req.url.path.endsWith('/history')) {
        return jsonResp({'data': [
          {'id': 1, 'estado': 'sos', 'origen': {'direccion': 'A'}, 'destino': {'direccion': 'B'}},
        ]});
      }
      return jsonResp({'id': 2, 'estado': 'pendiente_confirmacion', 'origen': {'direccion': 'A'}, 'destino': {'direccion': 'B'}});
    }, () async {
      await tester.pumpWidget(const MaterialApp(home: OffersScreen()));
      await avanzar(tester);
      await tester.tap(find.text('Viaje activo'));
      await avanzar(tester);
      expect(find.text('Esperando confirmación del cliente'), findsOneWidget);
      expect(find.text('pendiente_confirmacion'), findsNothing);
      await tester.tap(find.text('Historial'));
      await avanzar(tester);
      expect(find.text('sos'), findsNothing);
    });
  });

  casos.forEach((code, caso) {
    testWidgets('$code muestra el mensaje del backend tal cual', (tester) async {
      await ofertarCon(tester, caso.$1, caso.$2, code);
      expect(find.text(caso.$2), findsOneWidget);
      expect(find.textContaining('Error:'), findsNothing);
      // Sigue en la pantalla para poder corregir.
      expect(find.text('Hacer oferta'), findsOneWidget);
      // Suspendido por pago: diálogo con acceso directo a Pagos.
      expect(find.byKey(const Key('btn_ir_a_pagos')), code == 'CUENTA_SUSPENDIDA_POR_PAGO' ? findsOneWidget : findsNothing);
    });
  });
}
