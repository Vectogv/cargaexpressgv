import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:cargaexpress/contracts/validacion_usuario.dart' show cuerpoActualizacionPerfil;
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

  test('cuerpo de actualización: sin nombre ni teléfono vacíos; contacto vacío -> null; sin email', () {
    final body = cuerpoActualizacionPerfil(
      nombre: '  ',
      apellido: 'Pérez',
      telefono: '',
      contactoNombre: ' Luis ',
      contactoTelefono: '',
    );
    expect(body.containsKey('nombre'), isFalse);
    expect(body.containsKey('email'), isFalse);
    expect(body['apellido'], 'Pérez');
    // El validador del servidor no admite telefono: null (daría 422).
    expect(body.containsKey('telefono'), isFalse);
    expect(body['contactoEmergenciaNombre'], 'Luis');
    expect(body['contactoEmergenciaTelefono'], isNull);
  });

  testWidgets('editar perfil: el email no se puede editar ni se envía; contacto de emergencia sí', (tester) async {
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
      await tester.tap(find.text('Editar perfil'));
      await avanzar(tester);

      Finder campo(String label) => find.byKey(ValueKey('campo_$label'));
      expect(campo('Nombre del contacto'), findsOneWidget);
      expect(find.text('Luis'), findsOneWidget);

      final emailField = tester.widget<TextField>(campo('Correo'));
      expect(emailField.enabled, isFalse);

      // El teléfono propio es obligatorio: sin él, Guardar no manda el PUT.
      await tester.tap(find.text('Guardar cambios'));
      await avanzar(tester);
      expect(find.text('El teléfono es obligatorio'), findsOneWidget);
      expect(log.where((r) => r.method == 'PUT'), isEmpty);

      await tester.enterText(campo('Teléfono'), '3001112233');
      await tester.enterText(campo('Teléfono del contacto'), '3109876543');
      await tester.tap(find.text('Guardar cambios'));
      await avanzar(tester);
    }, log: log);
    final put = log.singleWhere((r) => r.method == 'PUT');
    expect(put.body, isNot(contains('"email"')));
    expect(put.body, contains('"telefono":"3001112233"'));
    expect(put.body, contains('"contactoEmergenciaTelefono":"3109876543"'));
  });

  testWidgets('guardar perfil: error del servidor no cierra la edición; reintentar con la portada elegida sí', (tester) async {
    pantallaAlta(tester);
    var intentosPut = 0;
    await conApiFalsa((req) {
      if (req.method == 'PUT') {
        intentosPut++;
        return intentosPut == 1 ? errorResp(500, 'Error del servidor') : jsonResp({'ok': true});
      }
      return jsonResp({'nombre': 'Ana', 'apellido': 'Pérez', 'email': 'ana@test.com'});
    }, () async {
      await tester.pumpWidget(const MaterialApp(home: PerfilScreen()));
      await avanzar(tester);
      await tester.tap(find.text('Editar perfil'));
      await avanzar(tester);

      await tester.enterText(find.byKey(const ValueKey('campo_Teléfono')), '3001112233');
      await tester.tap(find.byKey(const ValueKey('portada_ciudad')));
      await tester.tap(find.text('Guardar cambios'));
      await avanzar(tester);

      // Falla el servidor: la edición sigue abierta con el error, no se pierde lo escrito.
      expect(find.textContaining('Error del servidor'), findsOneWidget);
      expect(find.text('Guardar cambios'), findsOneWidget);

      await tester.tap(find.text('Guardar cambios'));
      await avanzar(tester);

      // Reintento exitoso: se cierra y el perfil muestra la portada elegida.
      expect(find.text('Guardar cambios'), findsNothing);
      final portada = tester.widget<PortadaPerfil>(find.byType(PortadaPerfil));
      expect(portada.id, 'ciudad');
    });
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
