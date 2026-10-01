import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cargaexpress/main.dart';
import 'package:cargaexpress/screens/user/auth_screen.dart';
import 'package:cargaexpress/screens/user/intro_screen.dart';
import 'package:cargaexpress/services/api_client.dart';

import '../helpers/fake_api.dart';

Future<void> _prefs(Map<String, Object> valores) async {
  SharedPreferences.setMockInitialValues(valores);
  await ApiClient.instance.init();
}

Future<bool?> _marca() async => (await SharedPreferences.getInstance()).getBool(ApiClient.introVistaKey);

void main() {
  testWidgets('sin la marca, la app abre con la intro', (tester) async {
    pantallaAlta(tester);
    await _prefs({});
    await tester.pumpWidget(const MainApp());
    await tester.pump();
    expect(find.byType(IntroScreen), findsOneWidget);
    expect(find.byType(AuthScreen), findsNothing);
    await avanzar(tester, 5); // deja terminar la escena
  });

  testWidgets('con la marca guardada, la intro no aparece', (tester) async {
    pantallaAlta(tester);
    await _prefs({'intro_vista': true});
    await tester.pumpWidget(const MainApp());
    await tester.pump();
    expect(find.byType(IntroScreen), findsNothing);
    expect(find.byType(AuthScreen), findsOneWidget);
  });

  testWidgets('Saltar guarda la marca y va a la bienvenida', (tester) async {
    pantallaAlta(tester);
    await _prefs({});
    await tester.pumpWidget(const MaterialApp(home: IntroScreen()));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.byKey(const Key('btn_saltar_intro')));
    await avanzar(tester, 1);
    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.byType(IntroScreen), findsNothing);
    expect(await _marca(), isTrue);
    expect(ApiClient.instance.introVista, isTrue);
  });

  testWidgets('al terminar la animación, sigue sola a la bienvenida', (tester) async {
    pantallaAlta(tester);
    await _prefs({});
    await tester.pumpWidget(const MaterialApp(home: IntroScreen()));
    await avanzar(tester, 4);
    expect(find.byType(AuthScreen), findsNothing);
    await avanzar(tester, 1);
    expect(find.byType(AuthScreen), findsOneWidget);
    expect(await _marca(), isTrue);
  });

  testWidgets('con animaciones desactivadas: cierre de marca fijo y sigue', (tester) async {
    pantallaAlta(tester);
    await _prefs({});
    await tester.pumpWidget(MaterialApp(
      builder: (context, hijo) =>
          MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: hijo!),
      home: const IntroScreen(),
    ));
    await tester.pump();
    expect(find.text('Tus fletes en Popayán, al instante'), findsOneWidget);
    expect(find.byType(AuthScreen), findsNothing);
    await avanzar(tester, 1.5);
    expect(find.byType(AuthScreen), findsOneWidget);
  });
}
