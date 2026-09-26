import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:cargaexpress/screens/shared/soporte_contacto.dart';
import 'package:cargaexpress/services/api_client.dart';

import '../../helpers/fake_api.dart';

/// [ContactoSoporteSection] es el widget compartido entre las pantallas de
/// Soporte del cliente y del conductor: GET /api/support/help es público, así
/// que también se consulta y muestra sin sesión.
void main() {
  final ayuda = {
    'faq': [
      {'pregunta': '¿Cómo funciona el pago?', 'respuesta': 'En efectivo al terminar el servicio.'},
    ],
    'contacto': {'email': 'soporte@cargaexpress.co', 'telefono': '+57 300 000 0000'},
  };

  testWidgets('sin sesión consulta /api/support/help sin Authorization y muestra teléfono, correo y FAQ', (tester) async {
    pantallaAlta(tester);
    expect(ApiClient.instance.token, isNull);
    final log = <http.Request>[];
    await conApiFalsa((req) => req.url.path == '/api/support/help' ? jsonResp(ayuda) : jsonResp([]), () async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ContactoSoporteSection())));
      await avanzar(tester);
      expect(find.text('+57 300 000 0000'), findsOneWidget);
      expect(find.text('soporte@cargaexpress.co'), findsOneWidget);
      expect(find.text('¿Cómo funciona el pago?'), findsOneWidget);
      expect(find.byKey(const Key('soporte_sin_sesion')), findsNothing);
    }, log: log);
    final help = log.singleWhere((r) => r.url.path == '/api/support/help');
    expect(help.headers.containsKey('Authorization'), isFalse);
  });

  testWidgets('si el backend falla se explica (sin sesión, con el aviso de cuenta suspendida)', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa((req) => req.url.path == '/api/support/help' ? errorResp(500, 'Error interno') : jsonResp([]), () async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ContactoSoporteSection())));
      await avanzar(tester);
      expect(find.byKey(const Key('soporte_sin_sesion')), findsOneWidget);
      final aviso = find.byKey(const Key('soporte_sin_sesion'));
      expect(find.descendant(of: aviso, matching: find.textContaining('No pudimos cargar los canales de contacto')), findsOneWidget);
      expect(find.descendant(of: aviso, matching: find.textContaining('inicia sesión igualmente')), findsOneWidget);
    });
  });
}
