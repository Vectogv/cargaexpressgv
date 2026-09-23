import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cargaexpress/contracts/validacion_usuario.dart';
import 'package:cargaexpress/screens/user/login_screen.dart';
import 'package:cargaexpress/screens/user/register_screen.dart';

import '../helpers/fake_api.dart';

void main() {
  group('reglas de app/validators/auth.ts y profile.ts', () {
    test('correo', () {
      expect(validarEmail('ana@test.com'), isNull);
      expect(validarEmail('  ana@test.co  '), isNull);
      expect(validarEmail('ana@test'), isNotNull);
      expect(validarEmail('ana test@x.com'), isNotNull);
      expect(validarEmail(''), isNotNull);
      expect(validarEmail('${'a' * 250}@x.com'), isNotNull); // > 254
    });

    test('contraseña de registro: 6 a 32 caracteres', () {
      expect(validarPasswordRegistro('12345'), isNotNull);
      expect(validarPasswordRegistro('123456'), isNull);
      expect(validarPasswordRegistro('a' * 32), isNull);
      expect(validarPasswordRegistro('a' * 33), isNotNull);
    });

    test('edad: 18 a 120', () {
      expect(validarEdad(''), 'La edad es obligatoria');
      expect(validarEdad('17'), isNotNull);
      expect(validarEdad('18'), isNull);
      expect(validarEdad('120'), isNull);
      expect(validarEdad('121'), isNotNull);
      expect(validarEdad('abc'), isNotNull);
    });

    test('longitudes máximas', () {
      expect(LimitesUsuario.nombre, 100);
      expect(LimitesUsuario.apellido, 100);
      expect(LimitesUsuario.telefono, 20);
      expect(LimitesUsuario.cedula, 20);
      expect(LimitesUsuario.placa, 20);
      expect(LimitesUsuario.capacidad, 50);
      expect(LimitesUsuario.ciudad, 100);
      expect(LimitesUsuario.contactoNombre, 100);
    });
  });

  testWidgets('login: correo inválido no llama al backend', (tester) async {
    pantallaAlta(tester);
    final log = <Object>[];
    await conApiFalsa((_) => jsonResp({}), () async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      final campos = find.byType(TextField);
      await tester.enterText(campos.at(0), 'ana@test');
      await tester.enterText(campos.at(1), 'x');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Iniciar Sesión'));
      await avanzar(tester);
      expect(find.text('Ingresa un correo electrónico válido'), findsOneWidget);
    }, log: log.cast());
    expect(log, isEmpty);
  });

  testWidgets('registro: contraseña corta y edad fuera de rango se avisan sin llamar al backend',
      (tester) async {
    pantallaAlta(tester);
    final log = <Object>[];
    await conApiFalsa((_) => jsonResp({}), () async {
      await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));
      final campos = find.byType(TextField);
      await tester.enterText(campos.at(0), 'Ana');
      await tester.enterText(campos.at(1), 'Pérez');
      await tester.enterText(campos.at(2), 'ana@test.com');
      await tester.enterText(campos.at(3), '123');
      final edad = find.byWidgetPredicate((w) => w is TextField && w.keyboardType == TextInputType.number);
      await tester.enterText(edad.first, '30');
      await tester.ensureVisible(find.text('Crear cuenta'));
      await tester.tap(find.text('Crear cuenta'));
      await avanzar(tester);
      expect(find.text('La contraseña debe tener entre 6 y 32 caracteres'), findsOneWidget);
      tester.state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger)).clearSnackBars();
      await avanzar(tester);

      await tester.enterText(campos.at(3), 'secreta123');
      await tester.enterText(edad.first, '130');
      await tester.tap(find.text('Crear cuenta'));
      await avanzar(tester);
      expect(find.text('Ingresa una edad válida (18 a 120 años)'), findsOneWidget);
    }, log: log.cast());
    expect(log, isEmpty);
  });

  testWidgets('registro: los campos respetan la longitud máxima del backend', (tester) async {
    pantallaAlta(tester);
    await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));
    final nombre = find.byType(TextField).at(0);
    await tester.enterText(nombre, 'x' * 150);
    expect(tester.widget<TextField>(nombre).controller!.text.length, 100);
  });
}
