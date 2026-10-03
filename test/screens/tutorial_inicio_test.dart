import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cargaexpress/screens/cliente/home_screen.dart';
import 'package:cargaexpress/screens/cliente/perfil_screen.dart';
import 'package:cargaexpress/screens/conductor/home_screen.dart';

import '../helpers/fake_api.dart';

http.Response _backend(http.Request req) => jsonResp({'data': []});

void main() {
  for (final rol in [
    (nombre: 'cliente', clave: 'tutorial_cliente_visto', home: const ClienteHomeScreen(), primero: 'Publica tu envío'),
    (nombre: 'conductor', clave: 'tutorial_conductor_visto', home: const HomeScreen(), primero: 'Conéctate'),
  ]) {
    testWidgets('tutorial del ${rol.nombre}: sale la primera vez y no vuelve', (tester) async {
      pantallaAlta(tester);
      await conApiFalsa(_backend, () async {
        SharedPreferences.setMockInitialValues({});
        await tester.pumpWidget(MaterialApp(home: rol.home));
        await avanzar(tester, 2);
        expect(find.text(rol.primero), findsOneWidget);
        expect(find.text('1 de 4'), findsOneWidget);

        for (var i = 0; i < 3; i++) {
          await tester.tap(find.text('Siguiente'));
          await avanzar(tester, 0.5);
        }
        await tester.tap(find.text('Entendido'));
        await avanzar(tester, 0.5);
        expect(find.text('Entendido'), findsNothing);
        expect((await SharedPreferences.getInstance()).getBool(rol.clave), isTrue);

        // Con la marca puesta no sale de nuevo.
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(MaterialApp(home: rol.home));
        await avanzar(tester, 2);
        expect(find.text(rol.primero), findsNothing);
        await tester.pumpWidget(const SizedBox());
        await avanzar(tester, 1);
      });
    });
  }

  testWidgets('perfil del cliente: "Número de emergencia" abre el diálogo con el contacto guardado', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa((req) {
      if (req.method == 'PUT') return jsonResp({'ok': true});
      return jsonResp({
        'nombre': 'Ana',
        'email': 'ana@test.com',
        'contactoEmergenciaNombre': 'Luis',
        'contactoEmergenciaTelefono': '3001234567',
      });
    }, () async {
      await tester.pumpWidget(const MaterialApp(home: PerfilScreen()));
      await avanzar(tester);
      await tester.scrollUntilVisible(find.text('Número de emergencia'), 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Número de emergencia'));
      await avanzar(tester, 0.5);
      expect(find.text('Luis'), findsOneWidget);
      expect(find.text('3001234567'), findsOneWidget);
      await tester.tap(find.text('Guardar'));
      await avanzar(tester, 0.5);
      expect(find.text('Contacto de emergencia actualizado'), findsOneWidget);
    });
  });
}
