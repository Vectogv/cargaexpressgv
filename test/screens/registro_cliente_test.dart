import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cargaexpress/screens/cliente/home_screen.dart';
import 'package:cargaexpress/screens/user/login_screen.dart';
import 'package:cargaexpress/screens/user/registro/registro_cliente.dart';
import 'package:cargaexpress/services/api_client.dart';
import 'package:cargaexpress/services/session_monitor_service.dart';
import 'package:cargaexpress/services/socket_service_client.dart';

import '../helpers/fake_api.dart';

final _idToken = 'x' * 40;

/// Backend del alta del cliente: registro con `perfilCompleto: false`, perfil
/// y el inicio del cliente.
http.Response _backend(http.Request req) {
  final p = req.url.path;
  if (p == '/api/auth/register' || p == '/api/auth/login') {
    return jsonResp({'token': 'tk', 'refreshToken': 'rt', 'id': 'u1', 'nombre': 'Ana', 'rol': 'cliente', 'perfilCompleto': false});
  }
  if (p == '/api/users/profile') return jsonResp({'nombre': 'Ana', 'telefono': '3001234567', 'edad': null, 'cedula': null, 'registroCompleto': false});
  if (p == '/api/auth/google') {
    return jsonResp({
      'message': 'No tienes cuenta',
      'code': 'CUENTA_NO_EXISTE',
      'google': {'nombre': 'Ana', 'apellido': 'Pérez', 'email': 'ana@gmail.com', 'foto': null},
    }, 404);
  }
  if (p == '/api/trips/active') return errorResp(404, 'Sin viaje');
  return jsonResp({'data': []});
}

Future<void> _abrir(WidgetTester tester, {Widget? pantalla}) async {
  pantallaAlta(tester);
  await tester.pumpWidget(MaterialApp(home: pantalla ?? RegistroClienteScreen(obtenerIdToken: () async => _idToken)));
  await avanzar(tester, 0.5);
}

/// Toca "Continuar" y deja terminar la transición entre pantallas.
Future<void> _siguiente(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('btn_continuar')));
  await avanzar(tester, 0.5);
}

Future<void> _escribir(WidgetTester tester, String paso, String texto) async {
  expect(find.byKey(Key('campo_$paso')), findsOneWidget, reason: 'debería estar en el paso $paso');
  await tester.enterText(find.byKey(Key('campo_$paso')), texto);
  await _siguiente(tester);
}

Future<void> _datosConCorreo(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('btn_registro_correo')));
  await avanzar(tester, 0.5);
  for (final (paso, texto) in [('nombre', 'Ana'), ('apellido', 'Pérez'), ('telefono', '3001234567'), ('email', 'ana@test.com'), ('password', 'secreta123')]) {
    await _escribir(tester, paso, texto);
  }
}

Future<void> _login(WidgetTester tester) async {
  final campos = find.byType(TextField);
  await tester.enterText(campos.at(0), 'ana@test.com');
  await tester.enterText(campos.at(1), 'secreta123');
  await tester.tap(find.byKey(const Key('btn_login')));
  await avanzar(tester);
}

Future<void> _limpiar(WidgetTester tester) async {
  SessionMonitorService.instance.stop();
  SocketServiceClient.instance.disconnect();
  await ApiClient.instance.clearTokens();
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 30));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    return ApiClient.instance.clearTokens();
  });

  testWidgets('con correo: crea la cuenta sin edad, luego guarda edad y cédula, acepta políticas y abre el inicio', (tester) async {
    final log = <http.Request>[];
    await conApiFalsa(_backend, () async {
      await _abrir(tester);
      expect(find.text('Bienvenido a Carga Express'), findsOneWidget);
      expect(find.text('Continuar con Google'), findsOneWidget);
      await _datosConCorreo(tester);

      // Confirmación distinta: no avanza ni llama al servidor.
      await _escribir(tester, 'password2', 'otra12345');
      expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
      expect(log.where((r) => r.url.path == '/api/auth/register'), isEmpty);
      expect(find.text('Crear cuenta'), findsOneWidget);
      await _escribir(tester, 'password2', 'secreta123');

      // Cuenta creada: ya no se puede volver a los datos de la cuenta.
      expect(find.byKey(const Key('campo_edad')), findsOneWidget);
      expect(find.byKey(const Key('btn_atras')), findsNothing);
      expect(find.byKey(const Key('btn_otra_cuenta')), findsOneWidget);
      // Menor de edad: no se envía nada.
      await _escribir(tester, 'edad', '16');
      expect(find.text('Ingresa una edad válida (18 a 120 años)'), findsOneWidget);
      await _escribir(tester, 'edad', '30');
      // La cédula es opcional: se puede dejar vacía.
      expect(find.text('Cédula (opcional)'), findsOneWidget);
      await _escribir(tester, 'cedula', '123456');

      expect(find.text('Antes de empezar'), findsOneWidget);
      expect(find.text('Aceptar y continuar'), findsOneWidget);
      await _siguiente(tester);
      expect(find.text('Registro completado'), findsOneWidget);
      expect(ApiClient.instance.perfilCompleto, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('auth_perfil_completo'), isNull);
      expect(prefs.getString(claveBorradorRegistroCliente), isNull, reason: 'el borrador se borra al crear la cuenta');

      await tester.tap(find.byKey(const Key('btn_ir_panel')));
      await avanzar(tester);
      expect(find.byType(ClienteHomeScreen), findsOneWidget);
      await _limpiar(tester);
    }, log: log);

    final registros = log.where((r) => r.url.path == '/api/auth/register').toList();
    expect(registros, hasLength(1));
    expect(jsonDecode(registros.single.body), {
      'nombre': 'Ana',
      'apellido': 'Pérez',
      'email': 'ana@test.com',
      'password': 'secreta123',
      'rol': 'cliente',
      'telefono': '3001234567',
    });
    final puts = log.where((r) => r.method == 'PUT' && r.url.path == '/api/users/profile').toList();
    expect(puts.map((r) => jsonDecode(r.body)), [
      {'edad': 30, 'cedula': '123456'},
      {'aceptaTerminos': true},
    ]);
    expect(puts.first.headers['Authorization'], 'Bearer tk');
  });

  testWidgets('con Google (404 CUENTA_NO_EXISTE): confirma nombre y apellido, el correo no se cambia y manda idToken sin contraseña', (tester) async {
    final log = <http.Request>[];
    await conApiFalsa(_backend, () async {
      await _abrir(tester);
      await tester.tap(find.byKey(const Key('btn_google')));
      await avanzar(tester, 0.5);
      expect(find.text('Confirma tus datos'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const Key('campo_nombre'))).controller?.text, 'Ana');
      expect(tester.widget<TextField>(find.byKey(const Key('campo_email'))).enabled, isFalse);
      await _siguiente(tester);
      expect(find.text('Crear cuenta'), findsOneWidget);
      await _escribir(tester, 'telefono', '3001234567');
      expect(find.byKey(const Key('campo_password')), findsNothing);
      expect(find.byKey(const Key('campo_edad')), findsOneWidget);
      await _limpiar(tester);
    }, log: log);

    final body = jsonDecode(log.singleWhere((r) => r.url.path == '/api/auth/register').body) as Map<String, dynamic>;
    expect(body, {'nombre': 'Ana', 'apellido': 'Pérez', 'email': 'ana@gmail.com', 'idToken': _idToken, 'rol': 'cliente', 'telefono': '3001234567'});
  });

  testWidgets('correo ya usado (409 EMAIL_DUPLICADO): vuelve al paso del correo con el motivo', (tester) async {
    final log = <http.Request>[];
    await conApiFalsa((req) {
      if (req.url.path == '/api/auth/register') return errorResp(409, 'Ese correo ya está registrado.', 'EMAIL_DUPLICADO');
      return _backend(req);
    }, () async {
      await _abrir(tester);
      await _datosConCorreo(tester);
      await _escribir(tester, 'password2', 'secreta123');
      expect(find.byKey(const Key('campo_email')), findsOneWidget);
      expect(find.text('Ese correo ya está registrado.'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(ApiClient.instance.token, isNull);
    }, log: log);
  });

  testWidgets('vacío: no avanza ni llama al servidor', (tester) async {
    final log = <http.Request>[];
    await conApiFalsa(_backend, () async {
      await _abrir(tester);
      await tester.tap(find.byKey(const Key('btn_registro_correo')));
      await avanzar(tester, 0.5);
      await _siguiente(tester);
      expect(find.text('Este campo es obligatorio'), findsOneWidget);
      expect(find.byKey(const Key('campo_nombre')), findsOneWidget);
    }, log: log);
    expect(log, isEmpty);
  });

  testWidgets('al avanzar se guarda un borrador sin contraseña y se retoma en el primer paso incompleto', (tester) async {
    await conApiFalsa(_backend, () async {
      await _abrir(tester);
      await _datosConCorreo(tester);
      final prefs = await SharedPreferences.getInstance();
      final b = jsonDecode(prefs.getString(claveBorradorRegistroCliente)!) as Map<String, dynamic>;
      expect(b['metodo'], 'correo');
      expect(b['paso'], 'password2');
      expect(b['campos']['email'], 'ana@test.com');
      expect(jsonEncode(b).contains('secreta123'), isFalse);

      // Vuelve a abrir (pantalla nueva): ofrece continuar y salta a la contraseña (nunca se guarda).
      await tester.pumpWidget(const SizedBox());
      await _abrir(tester);
      expect(find.text('Continúa tu registro'), findsOneWidget);
      await tester.tap(find.byKey(const Key('btn_continuar_registro')));
      await avanzar(tester, 0.5);
      expect(find.byKey(const Key('campo_password')), findsOneWidget);
      await tester.tap(find.byKey(const Key('btn_atras')));
      await avanzar(tester, 0.5);
      expect(tester.widget<TextField>(find.byKey(const Key('campo_email'))).controller?.text, 'ana@test.com');
    });
  });

  testWidgets('login con perfilCompleto:false lleva al asistente con lo que falta (edad, cédula y políticas)', (tester) async {
    final log = <http.Request>[];
    await conApiFalsa(_backend, () async {
      await _abrir(tester, pantalla: const LoginScreen());
      await _login(tester);
      expect(find.byType(RegistroClienteScreen), findsOneWidget);
      expect(find.byType(ClienteHomeScreen), findsNothing);
      // El teléfono ya estaba: empieza en la edad y no deja volver.
      expect(find.byKey(const Key('campo_edad')), findsOneWidget);
      expect(find.byKey(const Key('btn_atras')), findsNothing);
      await _escribir(tester, 'edad', '30');
      await _siguiente(tester); // cédula vacía
      expect(find.text('Antes de empezar'), findsOneWidget);
      await _siguiente(tester);
      expect(find.text('Registro completado'), findsOneWidget);
      expect(ApiClient.instance.perfilCompleto, isTrue);
      await _limpiar(tester);
    }, log: log);
    final puts = log.where((r) => r.method == 'PUT').map((r) => jsonDecode(r.body)).toList();
    expect(puts, [
      {'edad': 30},
      {'aceptaTerminos': true},
    ]);
  });

  testWidgets('login con perfilCompleto:true entra directo al inicio', (tester) async {
    await conApiFalsa((req) {
      if (req.url.path == '/api/auth/login') {
        return jsonResp({'token': 'tk', 'refreshToken': 'rt', 'id': 'u1', 'nombre': 'Ana', 'rol': 'cliente', 'perfilCompleto': true});
      }
      return _backend(req);
    }, () async {
      await _abrir(tester, pantalla: const LoginScreen());
      await _login(tester);
      expect(find.byType(ClienteHomeScreen), findsOneWidget);
      expect(find.byType(RegistroClienteScreen), findsNothing);
      await _limpiar(tester);
    });
  });
}
