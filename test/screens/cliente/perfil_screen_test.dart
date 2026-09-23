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
