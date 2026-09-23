import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:cargaexpress/screens/cliente/home_screen.dart';
import 'package:cargaexpress/screens/user/auth_screen.dart';
import 'package:cargaexpress/screens/user/login_screen.dart';
import 'package:cargaexpress/screens/user/register_screen.dart';
import 'package:cargaexpress/services/api_client.dart';
import 'package:cargaexpress/services/session_monitor_service.dart';
import 'package:cargaexpress/services/socket_service_client.dart';

import '../helpers/fake_api.dart';

Future<void> _llenarLogin(WidgetTester tester) async {
  final campos = find.byType(TextField);
  await tester.enterText(campos.at(0), 'ana@test.com');
  await tester.enterText(campos.at(1), 'secreta123');
  await tester.tap(find.widgetWithText(ElevatedButton, 'Iniciar Sesión'));
  await avanzar(tester);
}

void main() {
  tearDown(() => SessionMonitorService.instance.stop());

  testWidgets('Auth -> Login y Auth -> Registro', (tester) async {
    pantallaAlta(tester);
    await tester.pumpWidget(const MaterialApp(home: AuthScreen()));
    await tester.tap(find.text('Iniciar Sesión'));
    await avanzar(tester);
    expect(find.byType(LoginScreen), findsOneWidget);

    await tester.pageBack();
    await avanzar(tester);
    await tester.tap(find.text('Registrarse'));
    await avanzar(tester);
    expect(find.byType(RegisterScreen), findsOneWidget);
  });

  testWidgets('login con credenciales inválidas: mensaje claro y botón activo', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa((_) => errorResp(400, 'Invalid user credentials'), () async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await _llenarLogin(tester);
      expect(find.text('Correo o contraseña incorrectos'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.widgetWithText(ElevatedButton, 'Iniciar Sesión'), findsOneWidget);
    });
  });

  testWidgets('login sin conexión: mensaje de red y sin spinner colgado', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa((_) => throw http.ClientException('sin red'), () async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await _llenarLogin(tester);
      expect(find.textContaining('Sin conexión'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  testWidgets('login correcto de cliente abre su inicio', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa((req) {
      if (req.url.path == '/api/auth/login') {
        return jsonResp({
          'token': 'tk',
          'refreshToken': 'rt',
          'id': 'u1',
          'nombre': 'Ana',
          'apellido': 'P',
          'email': 'ana@test.com',
          'rol': 'cliente',
        });
      }
      if (req.url.path == '/api/trips/active') return errorResp(404, 'Sin viaje');
      return jsonResp({'data': []});
    }, () async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await _llenarLogin(tester);
      expect(find.byType(ClienteHomeScreen), findsOneWidget);
      expect(SessionMonitorService.instance.activo, isTrue);
      // Limpieza: timers del monitor y del intento de conexión del socket.
      SessionMonitorService.instance.stop();
      SocketServiceClient.instance.disconnect();
      await ApiClient.instance.clearTokens();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 30));
    });
  });

  testWidgets('registro con correo ya usado (409): se muestra el motivo', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa((_) => errorResp(409, 'El correo ya está registrado'), () async {
      await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));
      final campos = find.byType(TextField);
      await tester.enterText(campos.at(0), 'Ana');
      await tester.enterText(campos.at(1), 'Pérez');
      await tester.enterText(campos.at(2), 'ana@test.com');
      await tester.enterText(campos.at(3), 'secreta123');
      // Edad: el campo con teclado numérico.
      final edad = find.byWidgetPredicate((w) => w is TextField && w.keyboardType == TextInputType.number);
      await tester.enterText(edad.first, '30');
      await tester.ensureVisible(find.text('Crear cuenta'));
      await tester.tap(find.text('Crear cuenta'));
      await avanzar(tester);
      expect(find.text('El correo ya está registrado'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
