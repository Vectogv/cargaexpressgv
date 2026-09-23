import 'dart:async';
import 'dart:convert';

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
  await tester.tap(find.byKey(const Key('btn_login')));
  await avanzar(tester);
}

/// Teléfono pequeño (360x640 dp) con escala de texto opcional.
Future<void> _pantallaPequena(WidgetTester tester, Widget screen, {double escala = 1.0}) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: const Size(360, 640), textScaler: TextScaler.linear(escala)),
      child: screen,
    ),
  ));
  await tester.pump();
}

void main() {
  tearDown(() => SessionMonitorService.instance.stop());

  group('bienvenida', () {
    testWidgets('Auth -> Login y Auth -> Registro', (tester) async {
      pantallaAlta(tester);
      await tester.pumpWidget(const MaterialApp(home: AuthScreen()));
      await tester.tap(find.byKey(const Key('btn_ir_login')));
      await avanzar(tester);
      expect(find.byType(LoginScreen), findsOneWidget);

      await tester.pageBack();
      await avanzar(tester);
      await tester.tap(find.byKey(const Key('btn_ir_registro')));
      await avanzar(tester);
      expect(find.byType(RegisterScreen), findsOneWidget);
    });

    testWidgets('muestra la marca y la propuesta, sin restos de wireframe ni botón de Google', (tester) async {
      pantallaAlta(tester);
      await tester.pumpWidget(const MaterialApp(home: AuthScreen()));
      expect(find.text('Envía tu carga sin complicaciones'), findsOneWidget);
      expect(find.text('Iniciar sesión'), findsOneWidget);
      expect(find.text('Crear cuenta'), findsOneWidget);
      expect(find.textContaining('/api/'), findsNothing);
      expect(find.textContaining('LOGIN'), findsNothing);
      expect(find.text('or'), findsNothing);
      expect(find.byType(Image), findsNothing);
    });
  });

  group('login', () {
    testWidgets('campos vacíos: errores en línea y sin llamar al backend', (tester) async {
      pantallaAlta(tester);
      final log = <http.Request>[];
      await conApiFalsa((_) => jsonResp({}), () async {
        await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
        await tester.tap(find.byKey(const Key('btn_login')));
        await avanzar(tester);
        expect(find.text('Ingresa tu correo electrónico'), findsOneWidget);
        expect(find.text('Ingresa tu contraseña'), findsOneWidget);
      }, log: log);
      expect(log, isEmpty);
    });

    testWidgets('mostrar/ocultar contraseña', (tester) async {
      pantallaAlta(tester);
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      TextField pass() => tester.widget<TextField>(find.byType(TextField).at(1));
      expect(pass().obscureText, isTrue);
      await tester.tap(find.byTooltip('Mostrar contraseña'));
      await tester.pump();
      expect(pass().obscureText, isFalse);
      expect(find.byTooltip('Ocultar contraseña'), findsOneWidget);
    });

    testWidgets('mientras espera al backend el botón muestra que está ingresando', (tester) async {
      pantallaAlta(tester);
      final respuesta = Completer<http.Response>();
      await conApiFalsa((_) => respuesta.future, () async {
        await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
        await _llenarLogin(tester);
        expect(find.text('Ingresando...'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        respuesta.complete(errorResp(400, 'Invalid user credentials'));
        await avanzar(tester);
        expect(find.text('Ingresando...'), findsNothing);
      });
    });

    testWidgets('credenciales inválidas: mensaje claro en la tarjeta y botón activo', (tester) async {
      pantallaAlta(tester);
      await conApiFalsa((_) => errorResp(400, 'Invalid user credentials'), () async {
        await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
        await _llenarLogin(tester);
        expect(find.text('Correo o contraseña incorrectos'), findsOneWidget);
        expect(find.byKey(const Key('aviso_error_auth')), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.widgetWithText(FilledButton, 'Iniciar sesión'), findsOneWidget);
      });
    });

    testWidgets('cuenta bloqueada (403): se muestra el motivo del backend', (tester) async {
      pantallaAlta(tester);
      await conApiFalsa((_) => errorResp(403, 'Tu cuenta está suspendida'), () async {
        await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
        await _llenarLogin(tester);
        expect(find.text('Tu cuenta está suspendida'), findsOneWidget);
      });
    });

    testWidgets('sin conexión: mensaje de red y sin spinner colgado', (tester) async {
      pantallaAlta(tester);
      await conApiFalsa((_) => throw http.ClientException('sin red'), () async {
        await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
        await _llenarLogin(tester);
        expect(find.textContaining('Sin conexión'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      });
    });

    testWidgets('"Regístrate" abre el registro', (tester) async {
      pantallaAlta(tester);
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await tester.tap(find.byKey(const Key('link_registro')));
      await avanzar(tester);
      expect(find.byType(RegisterScreen), findsOneWidget);
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
  });

  group('registro', () {
    Future<void> llenarDatosPersonales(WidgetTester tester) async {
      final campos = find.byType(TextField);
      await tester.enterText(campos.at(0), 'Ana');
      await tester.enterText(campos.at(1), 'Pérez');
      await tester.enterText(campos.at(2), 'ana@test.com');
      await tester.enterText(campos.at(3), 'secreta123');
      // Edad: el primer campo con teclado numérico.
      final edad = find.byWidgetPredicate((w) => w is TextField && w.keyboardType == TextInputType.number);
      await tester.enterText(edad.first, '30');
    }

    testWidgets('correo ya usado (409): se muestra el motivo', (tester) async {
      pantallaAlta(tester);
      await conApiFalsa((_) => errorResp(409, 'El correo ya está registrado'), () async {
        await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));
        await llenarDatosPersonales(tester);
        await tester.ensureVisible(find.text('Crear cuenta'));
        await tester.tap(find.text('Crear cuenta'));
        await avanzar(tester);
        expect(find.text('El correo ya está registrado'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      });
    });

    testWidgets('vacío: campos obligatorios marcados y aviso junto al botón', (tester) async {
      pantallaAlta(tester);
      final log = <http.Request>[];
      await conApiFalsa((_) => jsonResp({}), () async {
        await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));
        await tester.ensureVisible(find.text('Crear cuenta'));
        await tester.tap(find.text('Crear cuenta'));
        await avanzar(tester);
        expect(find.text('Este campo es obligatorio'), findsNWidgets(2));
        expect(find.text('Ingresa tu correo electrónico'), findsOneWidget);
        expect(find.text('La edad es obligatoria'), findsOneWidget);
        expect(find.text('Revisa los campos marcados en rojo.'), findsOneWidget);
      }, log: log);
      expect(log, isEmpty);
    });

    testWidgets('menor de edad: se avisa sin llamar al backend', (tester) async {
      pantallaAlta(tester);
      final log = <http.Request>[];
      await conApiFalsa((_) => jsonResp({}), () async {
        await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));
        await llenarDatosPersonales(tester);
        final edad = find.byWidgetPredicate((w) => w is TextField && w.keyboardType == TextInputType.number);
        await tester.enterText(edad.first, '16');
        await tester.ensureVisible(find.text('Crear cuenta'));
        await tester.tap(find.text('Crear cuenta'));
        await avanzar(tester);
        expect(find.text('Debes ser mayor de 18 años para registrarte'), findsOneWidget);
      }, log: log);
      expect(log, isEmpty);
    });

    testWidgets('conductor: tarjeta de rol, sección de vehículo y datos enviados al backend', (tester) async {
      pantallaAlta(tester);
      final log = <http.Request>[];
      await conApiFalsa((_) => errorResp(409, 'La placa ya está registrada'), () async {
        await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));
        expect(find.text('Conductor y vehículo'), findsNothing);
        await tester.tap(find.byKey(const Key('rol_conductor')));
        await tester.pump();
        expect(find.text('Conductor y vehículo'), findsOneWidget);

        await llenarDatosPersonales(tester);
        await tester.ensureVisible(find.text('Crear cuenta'));
        await tester.tap(find.text('Crear cuenta'));
        await avanzar(tester);
        // Faltan cédula, placa y capacidad.
        expect(find.text('Este campo es obligatorio'), findsNWidgets(3));

        await tester.enterText(find.widgetWithText(TextField, 'Cédula'), '123456');
        await tester.enterText(find.widgetWithText(TextField, 'Placa'), 'abc123');
        await tester.enterText(find.widgetWithText(TextField, 'Capacidad'), '500 kg');
        await tester.enterText(find.widgetWithText(TextField, 'Ciudad (zona de cobertura)'), 'Cali');
        await tester.tap(find.text('Crear cuenta'));
        await avanzar(tester);
        expect(find.text('La placa ya está registrada'), findsOneWidget);
      }, log: log);
      final body = jsonDecode(log.single.body) as Map<String, dynamic>;
      expect(log.single.url.path, '/api/auth/register');
      expect(body['rol'], 'conductor');
      expect(body['placa'], 'ABC123');
      expect(body['cedula'], '123456');
      expect(body['tipoVehiculo'], 'Motocicleta');
      expect(body['capacidad'], '500 kg');
      expect(body['ciudad'], 'Cali');
      expect(body['edad'], 30);
    });

    testWidgets('"Inicia sesión" abre el login', (tester) async {
      pantallaAlta(tester);
      await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));
      await tester.ensureVisible(find.byKey(const Key('link_login')));
      await tester.tap(find.byKey(const Key('link_login')));
      await avanzar(tester);
      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });

  group('pantalla pequeña (360x640) sin desbordes', () {
    for (final escala in [1.0, 1.3]) {
      testWidgets('bienvenida, texto x$escala', (tester) async {
        await _pantallaPequena(tester, const AuthScreen(), escala: escala);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.byKey(const Key('btn_ir_registro')));
        expect(find.byKey(const Key('btn_ir_registro')).hitTestable(), findsOneWidget);
      });

      testWidgets('login con error, texto x$escala', (tester) async {
        await conApiFalsa((_) => errorResp(400, 'Invalid user credentials'), () async {
          await _pantallaPequena(tester, const LoginScreen(), escala: escala);
          await _llenarLogin(tester);
          expect(find.text('Correo o contraseña incorrectos'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      });

      testWidgets('registro de conductor con errores, texto x$escala', (tester) async {
        await _pantallaPequena(tester, const RegisterScreen(), escala: escala);
        await tester.tap(find.byKey(const Key('rol_conductor')));
        await tester.pump();
        await tester.ensureVisible(find.text('Crear cuenta'));
        await tester.tap(find.text('Crear cuenta'));
        await avanzar(tester);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
