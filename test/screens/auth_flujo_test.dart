import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cargaexpress/screens/cliente/home_screen.dart';
import 'package:cargaexpress/screens/user/auth_screen.dart';
import 'package:cargaexpress/screens/user/login_screen.dart';
import 'package:cargaexpress/screens/user/registro/registro_cliente.dart';
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
  // El asistente de registro lee su borrador de SharedPreferences.
  setUp(() => SharedPreferences.setMockInitialValues({}));
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
      expect(find.byType(RegistroClienteScreen), findsOneWidget);
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
      expect(find.byType(RegistroClienteScreen), findsOneWidget);
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
    // El flujo completo del asistente está en registro_cliente_test.dart.
    testWidgets('vacío: el primer paso no avanza ni llama al backend', (tester) async {
      pantallaAlta(tester);
      final log = <http.Request>[];
      await conApiFalsa((_) => jsonResp({}), () async {
        await tester.pumpWidget(const MaterialApp(home: RegistroClienteScreen()));
        await avanzar(tester, 0.5);
        expect(find.text('Bienvenido a Carga Express'), findsOneWidget);
        await tester.tap(find.byKey(const Key('btn_registro_correo')));
        await avanzar(tester, 0.5);
        await tester.tap(find.byKey(const Key('btn_continuar')));
        await avanzar(tester, 0.5);
        expect(find.text('Este campo es obligatorio'), findsOneWidget);
        expect(find.byKey(const Key('campo_nombre')), findsOneWidget);
      }, log: log);
      expect(log, isEmpty);
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

      testWidgets('registro del cliente con errores, texto x$escala', (tester) async {
        await _pantallaPequena(tester, const RegistroClienteScreen(), escala: escala);
        await avanzar(tester, 0.5);
        await tester.tap(find.byKey(const Key('btn_registro_correo')));
        await avanzar(tester, 0.5);
        await tester.tap(find.byKey(const Key('btn_continuar')));
        await avanzar(tester, 0.5);
        expect(find.text('Este campo es obligatorio'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
