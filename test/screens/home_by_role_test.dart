import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cargaexpress/screens/home_by_role.dart';
import 'package:cargaexpress/services/auth_response.dart';

void main() {
  group('homeDestinoFor (login, registro y restauración de sesión)', () {
    test('admin siempre va al panel de administración', () {
      expect(homeDestinoFor(rol: 'admin'), HomeDestino.admin);
      expect(homeDestinoFor(rol: 'admin', esModerador: true), HomeDestino.admin);
    });

    test('moderador (bandera esModerador o rol literal) va a su inicio', () {
      expect(homeDestinoFor(rol: 'cliente', esModerador: true), HomeDestino.moderador);
      expect(homeDestinoFor(rol: 'conductor', esModerador: true), HomeDestino.moderador);
      expect(homeDestinoFor(rol: 'moderador'), HomeDestino.moderador);
    });

    test('conductor y cliente', () {
      expect(homeDestinoFor(rol: 'conductor'), HomeDestino.conductor);
      expect(homeDestinoFor(rol: 'cliente'), HomeDestino.cliente);
    });

    test('rol desconocido no cae en el panel de admin', () {
      expect(homeDestinoFor(rol: 'otro'), HomeDestino.ninguno);
      expect(homeDestinoFor(rol: null), HomeDestino.ninguno);
    });
  });

  test('AuthResponse lee esModerador y zonaModerador del login', () {
    final auth = AuthResponse.fromJson({
      'token': 't',
      'id': '1',
      'rol': 'cliente',
      'esModerador': true,
      'zonaModerador': 'cali',
    });
    expect(auth.esModerador, isTrue);
    expect(auth.zonaModerador, 'cali');
    expect(homeDestinoFor(rol: auth.rol, esModerador: auth.esModerador), HomeDestino.moderador);

    final normal = AuthResponse.fromJson({'token': 't', 'rol': 'cliente'});
    expect(normal.esModerador, isFalse);
  });

  testWidgets(
      'tras login el inicio queda como primera ruta: popUntil(isFirst) '
      'no vuelve a la pantalla de autenticación', (tester) async {
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navKey,
      home: const Text('auth'),
    ));
    // AuthScreen -> push(LoginScreen), como en la app.
    navKey.currentState!.push(MaterialPageRoute(builder: (_) => const Text('login')));
    await tester.pumpAndSettle();

    abrirInicioComoRaiz(navKey.currentContext!, const Text('home'));
    await tester.pumpAndSettle();
    expect(navKey.currentState!.canPop(), isFalse);

    // Rastreo encima del inicio; cancelar hace popUntil(isFirst).
    navKey.currentState!.push(MaterialPageRoute(builder: (_) => const Text('rastreo')));
    await tester.pumpAndSettle();
    navKey.currentState!.popUntil((r) => r.isFirst);
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
    expect(find.text('auth'), findsNothing);
    expect(find.text('login'), findsNothing);
  });
}
