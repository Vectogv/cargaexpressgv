import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:cargaexpress/screens/conductor/mis_reservas_screen.dart';

import '../../helpers/fake_api.dart';

const _reserva = {
  'id': 70,
  'estado': 'reservado',
  'tipoProgramacion': 'programada',
  'fechaProgramada': '2026-10-05',
  'horaProgramada': '14:30',
  'origen': {'direccion': 'Calle 5 # 10-20'},
  'destino': {'direccion': 'Carrera 9 # 3-15'},
  'precioFinal': 90000,
  'cliente': {'nombre': 'Ana', 'apellido': 'Cliente'},
  'conductor': {'id': 40, 'nombre': 'Conductor Prueba'},
};

void main() {
  testWidgets('lista las reservas asignadas con chat y cancelar, sin Llamar', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa((_) => jsonResp({'data': [_reserva]}), () async {
      await tester.pumpWidget(const MaterialApp(home: MisReservasScreen()));
      await avanzar(tester);
      expect(find.text('Ana Cliente'), findsOneWidget);
      expect(find.textContaining('Calle 5 # 10-20'), findsOneWidget);
      expect(find.text('\$90.000'), findsOneWidget);
      expect(find.byKey(const Key('reserva_chat_70')), findsOneWidget);
      expect(find.byKey(const Key('reserva_cancelar_70')), findsOneWidget);
      expect(find.text('Llamar'), findsNothing);
    });
  });

  testWidgets('sin reservas muestra el estado vacío', (tester) async {
    await conApiFalsa((_) => jsonResp({'data': []}), () async {
      await tester.pumpWidget(const MaterialApp(home: MisReservasScreen()));
      await avanzar(tester);
      expect(find.text('No tienes reservas asignadas'), findsOneWidget);
    });
  });

  testWidgets('si falla la carga muestra el error con Reintentar', (tester) async {
    var intentos = 0;
    await conApiFalsa((_) => ++intentos == 1 ? errorResp(500) : jsonResp({'data': [_reserva]}), () async {
      await tester.pumpWidget(const MaterialApp(home: MisReservasScreen()));
      await avanzar(tester);
      expect(find.text('No pudimos cargar tus reservas'), findsOneWidget);
      await tester.tap(find.text('Reintentar'));
      await avanzar(tester);
      expect(find.text('Ana Cliente'), findsOneWidget);
    });
  });

  testWidgets('cancelar pide motivo y justificación, manda el POST y saca la reserva', (tester) async {
    pantallaAlta(tester);
    final log = <http.Request>[];
    await conApiFalsa((req) {
      if (req.method == 'POST' && req.url.path.endsWith('/cancel')) {
        return jsonResp({'message': 'ok', 'reabierta': true, 'penalizado': true});
      }
      return jsonResp({'data': [_reserva]});
    }, () async {
      await tester.pumpWidget(const MaterialApp(home: MisReservasScreen()));
      await avanzar(tester);
      await tester.tap(find.byKey(const Key('reserva_cancelar_70')));
      await avanzar(tester);
      expect(find.text('¿Por qué cancelas la reserva?'), findsOneWidget);
      expect(find.textContaining('se resta 0,5'), findsOneWidget);

      // Sin motivo ni justificación el botón rojo sigue deshabilitado.
      final confirmar = find.byKey(const Key('reserva_confirmar_cancelar'));
      expect(tester.widget<FilledButton>(find.descendant(of: confirmar, matching: find.byType(FilledButton))).enabled, isFalse);
      await tester.tap(find.text('Emergencia'));
      await avanzar(tester, 0.3);
      await tester.enterText(find.byKey(const Key('reserva_justificacion')), 'Se me dañó el carro hoy');
      await avanzar(tester, 0.3);
      await tester.tap(confirmar);
      await avanzar(tester);

      final post = log.firstWhere((r) => r.method == 'POST');
      expect(post.url.path, '/api/trips/70/cancel');
      final body = jsonDecode(post.body) as Map;
      expect(body['justificacion'], 'Se me dañó el carro hoy');
      expect(body['motivo'], contains('Emergencia'));
      expect(find.textContaining('Se restó 0,5'), findsOneWidget);
      expect(find.text('Ana Cliente'), findsNothing);
    }, log: log);
  });

  testWidgets('pedir más tiempo elige los minutos y manda el POST', (tester) async {
    pantallaAlta(tester);
    final log = <http.Request>[];
    await conApiFalsa((req) {
      if (req.method == 'POST' && req.url.path.endsWith('/plazo')) {
        return jsonResp({'plazo': {'minutos': 30, 'estado': 'pendiente'}});
      }
      return jsonResp({'data': [_reserva]});
    }, () async {
      await tester.pumpWidget(const MaterialApp(home: MisReservasScreen()));
      await avanzar(tester);
      expect(find.byKey(const Key('reserva_plazo_70')), findsOneWidget);
      await tester.tap(find.byKey(const Key('reserva_plazo_70')));
      await avanzar(tester);
      expect(find.text('¿Cuánto más necesitas?'), findsOneWidget);

      final confirmar = find.byKey(const Key('reserva_confirmar_plazo'));
      expect(tester.widget<FilledButton>(find.descendant(of: confirmar, matching: find.byType(FilledButton))).enabled, isFalse);
      await tester.tap(find.text('+30 min'));
      await avanzar(tester, 0.3);
      await tester.tap(confirmar);
      await avanzar(tester);

      final post = log.firstWhere((r) => r.method == 'POST');
      expect(post.url.path, '/api/trips/70/plazo');
      expect(jsonDecode(post.body), {'minutos': 30});
      expect(find.text('Se le pidió al cliente 30 min más. Esperando su respuesta.'), findsOneWidget);
      expect(find.text('Esperando respuesta del cliente'), findsOneWidget);
      expect(find.byKey(const Key('reserva_plazo_70')), findsNothing);
    }, log: log);
  });

  testWidgets('ya pedido el plazo muestra el chip y no el botón', (tester) async {
    pantallaAlta(tester);
    final reservaConPlazo = {..._reserva, 'plazo': {'minutos': 15, 'estado': 'pendiente'}};
    await conApiFalsa((_) => jsonResp({'data': [reservaConPlazo]}), () async {
      await tester.pumpWidget(const MaterialApp(home: MisReservasScreen()));
      await avanzar(tester);
      expect(find.byKey(const Key('reserva_plazo_70')), findsNothing);
      expect(find.text('Esperando respuesta del cliente'), findsOneWidget);
    });
  });

  testWidgets('pedir más tiempo ya pedido (409) muestra el mensaje del servidor', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa((req) {
      if (req.method == 'POST' && req.url.path.endsWith('/plazo')) {
        return errorResp(409, 'Ya pediste más tiempo para esta reserva.');
      }
      return jsonResp({'data': [_reserva]});
    }, () async {
      await tester.pumpWidget(const MaterialApp(home: MisReservasScreen()));
      await avanzar(tester);
      await tester.tap(find.byKey(const Key('reserva_plazo_70')));
      await avanzar(tester);
      await tester.tap(find.text('+15 min'));
      await avanzar(tester, 0.3);
      await tester.tap(find.byKey(const Key('reserva_confirmar_plazo')));
      await avanzar(tester);
      expect(find.text('Ya pediste más tiempo para esta reserva.'), findsOneWidget);
    });
  });
}
