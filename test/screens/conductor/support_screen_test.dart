import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:cargaexpress/screens/conductor/support_screen.dart';
import 'package:cargaexpress/services/api_client.dart';

import '../../helpers/fake_api.dart';

/// Pantalla de Soporte: GET /api/support/help es público en el backend, así
/// que teléfono y correo se muestran también sin sesión (cuenta suspendida
/// desde la bienvenida). Antes se saltaba la consulta sin token.
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
      await tester.pumpWidget(const MaterialApp(home: SupportScreen()));
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
      await tester.pumpWidget(const MaterialApp(home: SupportScreen()));
      await avanzar(tester);
      expect(find.byKey(const Key('soporte_sin_sesion')), findsOneWidget);
      final aviso = find.byKey(const Key('soporte_sin_sesion'));
      expect(find.descendant(of: aviso, matching: find.textContaining('No pudimos cargar los canales de contacto')), findsOneWidget);
      expect(find.descendant(of: aviso, matching: find.textContaining('inicia sesión igualmente')), findsOneWidget);
    });
  });
}
