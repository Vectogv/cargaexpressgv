import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cargaexpress/screens/cliente/home_screen.dart';
import 'package:cargaexpress/screens/user/auth_screen.dart';
import 'package:cargaexpress/screens/user/google_login.dart';
import 'package:cargaexpress/screens/user/registro/registro_cliente.dart';
import 'package:cargaexpress/services/api_client.dart';
import 'package:cargaexpress/services/session_monitor_service.dart';
import 'package:cargaexpress/services/socket_service_client.dart';

import '../helpers/fake_api.dart';

Widget _boton(Future<String?> Function() token) =>
    MaterialApp(home: Scaffold(body: BotonGoogleAuth(obtenerIdToken: token)));

Future<void> _limpiar(WidgetTester tester) async {
  SessionMonitorService.instance.stop();
  SocketServiceClient.instance.disconnect();
  await ApiClient.instance.clearTokens();
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 30));
}

Future<void> _escribir(WidgetTester tester, String paso, String texto) async {
  await tester.enterText(find.byKey(Key('campo_$paso')), texto);
  await _siguiente(tester);
}

Future<void> _siguiente(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('btn_continuar')));
  await avanzar(tester, 0.5);
}

void main() {
  final idToken = 'x' * 40;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    return ApiClient.instance.clearTokens();
  });

  testWidgets('cancelar el selector de Google no llama al servidor', (tester) async {
    final log = <http.Request>[];
    await conApiFalsa((req) => jsonResp({}), () async {
      await tester.pumpWidget(_boton(() async => null));
      await tester.tap(find.byKey(const Key('btn_google')));
      await avanzar(tester);
      expect(log, isEmpty);
      expect(find.text('Continuar con Google'), findsOneWidget);
    }, log: log);
  });

  testWidgets('error del servidor se muestra en el botón', (tester) async {
    await conApiFalsa((req) => errorResp(401, 'No se pudo validar tu cuenta de Google'), () async {
      await tester.pumpWidget(_boton(() async => idToken));
      await tester.tap(find.byKey(const Key('btn_google')));
      await avanzar(tester);
      expect(find.text('No se pudo validar tu cuenta de Google'), findsOneWidget);
    });
  });

  testWidgets('cliente con perfil incompleto: el asistente pide lo que falta y luego abre el inicio', (tester) async {
    pantallaAlta(tester);
    final log = <http.Request>[];
    await conApiFalsa((req) {
      if (req.url.path == '/api/auth/google') {
        return jsonResp({
          'token': 'tk',
          'refreshToken': 'rt',
          'id': 'u1',
          'nombre': 'Ana',
          'email': 'ana@gmail.com',
          'rol': 'cliente',
          'perfilCompleto': false,
        });
      }
      if (req.url.path == '/api/users/profile') {
        return jsonResp({'nombre': 'Ana', 'telefono': null, 'edad': null, 'cedula': null, 'registroCompleto': false});
      }
      if (req.url.path == '/api/trips/active') return errorResp(404, 'Sin viaje');
      return jsonResp({'data': []});
    }, () async {
      await tester.pumpWidget(_boton(() async => idToken));
      await tester.tap(find.byKey(const Key('btn_google')));
      await avanzar(tester);
      expect(find.byType(RegistroClienteScreen), findsOneWidget);
      final google = log.firstWhere((r) => r.url.path == '/api/auth/google');
      expect(jsonDecode(google.body), {'idToken': idToken});
      // Si cierra la app aquí, al volver a abrirla se le piden otra vez.
      await ApiClient.instance.init();
      expect(ApiClient.instance.perfilCompleto, isFalse);

      expect(find.byKey(const Key('campo_telefono')), findsOneWidget);
      expect(find.byKey(const Key('btn_atras')), findsNothing);
      await _escribir(tester, 'telefono', '3001234567');
      // Menor de edad: no se envía nada.
      await _escribir(tester, 'edad', '16');
      expect(log.where((r) => r.method == 'PUT'), isEmpty);
      await _escribir(tester, 'edad', '30');
      await _siguiente(tester); // cédula vacía (opcional)
      expect(find.text('Antes de empezar'), findsOneWidget);
      await _siguiente(tester);
      expect(find.text('Registro completado'), findsOneWidget);
      expect(ApiClient.instance.perfilCompleto, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('auth_perfil_completo'), isNull);

      await tester.tap(find.byKey(const Key('btn_ir_panel')));
      await avanzar(tester);
      expect(find.byType(ClienteHomeScreen), findsOneWidget);
      await _limpiar(tester);
    }, log: log);
    final puts = log.where((r) => r.method == 'PUT').map((r) => jsonDecode(r.body)).toList();
    expect(puts, [
      {'telefono': '3001234567', 'edad': 30},
      {'aceptaTerminos': true},
    ]);
  });

  testWidgets('correo sin cuenta (404 CUENTA_NO_EXISTE): "No tienes cuenta, regístrate" y abre el registro prellenado', (tester) async {
    pantallaAlta(tester);
    final log = <http.Request>[];
    await conApiFalsa((req) {
      if (req.url.path == '/api/auth/google') {
        return jsonResp({
          'message': 'No tienes cuenta',
          'code': 'CUENTA_NO_EXISTE',
          'google': {'nombre': 'Ana', 'apellido': 'Pérez', 'email': 'ana@gmail.com', 'foto': null},
        }, 404);
      }
      return jsonResp({});
    }, () async {
      await tester.pumpWidget(_boton(() async => idToken));
      await tester.tap(find.byKey(const Key('btn_google')));
      await avanzar(tester);
      expect(find.text('No tienes cuenta, regístrate'), findsOneWidget);
      // Sin flavor: asistente del cliente, prellenado y sin contraseña.
      expect(find.byType(RegistroClienteScreen), findsOneWidget);
      expect(find.text('Confirma tus datos'), findsOneWidget);
      expect(find.byKey(const Key('campo_password')), findsNothing);
      expect(tester.widget<TextField>(find.byKey(const Key('campo_email'))).enabled, isFalse);
      expect(tester.widget<TextField>(find.byKey(const Key('campo_nombre'))).controller?.text, 'Ana');
      expect(ApiClient.instance.token, isNull);
      expect(log.where((r) => r.url.path == '/api/auth/register'), isEmpty);
    }, log: log);
  });

  testWidgets('"Usar otra cuenta" cierra la sesión y vuelve al login', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa((req) {
      if (req.url.path == '/api/auth/google') {
        return jsonResp({
          'token': 'tk',
          'refreshToken': 'rt',
          'id': 'u2',
          'nombre': 'Luis',
          'email': 'luis@gmail.com',
          'rol': 'conductor',
          'perfilCompleto': false,
        });
      }
      return jsonResp({'data': []});
    }, () async {
      await tester.pumpWidget(_boton(() async => idToken));
      await tester.tap(find.byKey(const Key('btn_google')));
      await avanzar(tester);
      expect(find.byType(CompletarPerfilScreen), findsOneWidget);
      // Conductor: no se le dice "para que el conductor pueda llamarte".
      expect(find.textContaining('conductor pueda llamarte'), findsNothing);

      await tester.tap(find.byKey(const Key('btn_otra_cuenta_google')));
      await avanzar(tester);
      expect(find.byType(AuthScreen), findsOneWidget);
      expect(ApiClient.instance.token, isNull);
      expect(ApiClient.instance.perfilCompleto, isTrue);
      await _limpiar(tester);
    });
  });
}
