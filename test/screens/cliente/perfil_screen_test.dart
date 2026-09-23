import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:cargaexpress/screens/cliente/perfil_screen.dart';
import 'package:cargaexpress/screens/user/auth_screen.dart';

import '../../helpers/fake_api.dart';

void main() {
  testWidgets('cerrar sesión espera al logout antes de ir al login', (tester) async {
    pantallaAlta(tester);
    final logout = Completer<http.Response>();
    await conApiFalsa((req) {
      if (req.url.path == '/api/auth/logout') return logout.future;
      if (req.url.path == '/api/users/profile' || req.url.path.contains('profile')) {
        return jsonResp({'nombre': 'Ana', 'email': 'ana@test.com'});
      }
      return jsonResp({});
    }, () async {
      await tester.pumpWidget(const MaterialApp(home: PerfilScreen()));
      await avanzar(tester);

      await tester.tap(find.text('Cerrar sesión'));
      await avanzar(tester);
      expect(find.byType(AuthScreen), findsNothing);

      logout.complete(jsonResp({'ok': true}));
      await avanzar(tester);
      expect(find.byType(AuthScreen), findsOneWidget);
    });
  });

  test('cuerpo de actualización: sin nombre/apellido/correo vacíos; vacíos opcionales -> null', () {
    final body = cuerpoActualizacionPerfil(
      nombre: '  ',
      apellido: 'Pérez',
      email: '',
      telefono: '',
      contactoNombre: ' Luis ',
      contactoTelefono: '',
    );
    expect(body.containsKey('nombre'), isFalse);
    expect(body.containsKey('email'), isFalse);
    expect(body['apellido'], 'Pérez');
    expect(body['telefono'], isNull);
    expect(body.containsKey('telefono'), isTrue);
    expect(body['contactoEmergenciaNombre'], 'Luis');
    expect(body['contactoEmergenciaTelefono'], isNull);
  });

  testWidgets('editar perfil: correo inválido no se envía; contacto de emergencia sí', (tester) async {
    pantallaAlta(tester);
    final log = <http.Request>[];
    await conApiFalsa((req) {
      if (req.method == 'PUT') return jsonResp({'ok': true});
      return jsonResp({
        'nombre': 'Ana',
        'apellido': 'Pérez',
        'email': 'ana@test.com',
        'contactoEmergenciaNombre': 'Luis',
        'contactoEmergenciaTelefono': '3001234567',
      });
    }, () async {
      await tester.pumpWidget(const MaterialApp(home: PerfilScreen()));
      await avanzar(tester);
      await tester.tap(find.text('Información personal'));
      await avanzar(tester);

      expect(find.widgetWithText(TextField, 'Contacto de emergencia'), findsOneWidget);
      expect(find.text('Luis'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Email'), 'ana@malo');
      await tester.tap(find.text('Guardar'));
      await avanzar(tester);
      expect(find.text('Ingresa un correo electrónico válido'), findsOneWidget);
      expect(log.where((r) => r.method == 'PUT'), isEmpty);

      await tester.enterText(find.widgetWithText(TextField, 'Email'), 'ana@nuevo.com');
      await tester.enterText(find.widgetWithText(TextField, 'Teléfono del contacto'), '3109876543');
      await tester.tap(find.text('Guardar'));
      await avanzar(tester);
    }, log: log);
    final put = log.singleWhere((r) => r.method == 'PUT');
    expect(put.body, contains('"email":"ana@nuevo.com"'));
    expect(put.body, contains('"contactoEmergenciaTelefono":"3109876543"'));
  });

  testWidgets('si el perfil no carga se muestra el error', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa((_) => errorResp(500, 'Servidor caído'), () async {
      await tester.pumpWidget(const MaterialApp(home: PerfilScreen()));
      await avanzar(tester);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.textContaining('Servidor caído'), findsOneWidget);
    });
  });
}
