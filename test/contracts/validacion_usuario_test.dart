import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:cargaexpress/contracts/validacion_usuario.dart';
import 'package:cargaexpress/screens/user/login_screen.dart';
import 'package:cargaexpress/screens/user/registro/registro_cliente.dart';

import '../helpers/fake_api.dart';

/// Abre el asistente del cliente en el primer paso con correo.
Future<void> _registroConCorreo(WidgetTester tester) async {
  pantallaAlta(tester);
  await tester.pumpWidget(const MaterialApp(home: RegistroClienteScreen()));
  await avanzar(tester, 0.5);
  await tester.tap(find.byKey(const Key('btn_registro_correo')));
  await avanzar(tester, 0.5);
}

Future<void> _escribir(WidgetTester tester, String paso, String texto) async {
  await tester.enterText(find.byKey(Key('campo_$paso')), texto);
  await tester.tap(find.byKey(const Key('btn_continuar')));
  await avanzar(tester, 0.5);
}

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

    test('teléfono: obligatorio salvo opcional; solo dígitos, 7 a 15, "+" opcional', () {
      expect(validarTelefono(''), 'El teléfono es obligatorio');
      expect(validarTelefono('', opcional: true), isNull);
      expect(validarTelefono('123456'), isNotNull); // < 7 dígitos
      expect(validarTelefono('3001234567'), isNull);
      expect(validarTelefono('+573001234567'), isNull);
      expect(validarTelefono('300 123 4567'), isNotNull); // espacios no
      expect(validarTelefono('abc1234567'), isNotNull);
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
      await tester.tap(find.byKey(const Key('btn_login')));
      await avanzar(tester);
      expect(find.text('Ingresa un correo electrónico válido'), findsOneWidget);
    }, log: log.cast());
    expect(log, isEmpty);
  });

  testWidgets('registro: contraseña corta se avisa sin llamar al backend', (tester) async {
    final log = <http.Request>[];
    await conApiFalsa((_) => jsonResp({}), () async {
      await _registroConCorreo(tester);
      await _escribir(tester, 'nombre', 'Ana');
      await _escribir(tester, 'apellido', 'Pérez');
      await _escribir(tester, 'telefono', '3001234567');
      await _escribir(tester, 'email', 'ana@test.com');
      await _escribir(tester, 'password', '123');
      expect(find.text('La contraseña debe tener entre 6 y 32 caracteres'), findsOneWidget);
      expect(find.byKey(const Key('campo_password')), findsOneWidget);
    }, log: log);
    expect(log, isEmpty);
  });

  testWidgets('registro: edad fuera de rango se avisa sin guardar el perfil', (tester) async {
    final log = <http.Request>[];
    await conApiFalsa((_) => jsonResp({'telefono': '3001234567', 'edad': null, 'registroCompleto': false}), () async {
      pantallaAlta(tester);
      await tester.pumpWidget(const MaterialApp(home: RegistroClienteScreen.completar()));
      await avanzar(tester, 0.5);
      await _escribir(tester, 'edad', '130');
      expect(find.text('Ingresa una edad válida (18 a 120 años)'), findsOneWidget);
    }, log: log);
    expect(log.where((r) => r.method != 'GET'), isEmpty);
  });

  testWidgets('registro: los campos respetan la longitud máxima del backend', (tester) async {
    await conApiFalsa((_) => jsonResp({}), () async {
      await _registroConCorreo(tester);
      final nombre = find.byKey(const Key('campo_nombre'));
      await tester.enterText(nombre, 'x' * 150);
      expect(tester.widget<TextField>(nombre).controller!.text.length, 100);
    });
  });
}
