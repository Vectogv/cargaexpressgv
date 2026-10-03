import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cargaexpress/screens/user/registro_conductor/registro_conductor_screen.dart';
import 'package:cargaexpress/services/api_client.dart';
import 'package:cargaexpress/services/session_monitor_service.dart';
import 'package:cargaexpress/services/socket_service_client.dart';

import '../helpers/fake_api.dart';

/// PNG de 1x1 (válido para `Image.memory`).
final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

final _idToken = 'x' * 40;

/// Backend del alta: cobertura, registro OK y las dos fotos.
http.Response _backend(http.Request req) {
  final p = req.url.path;
  if (p == '/api/config/coverage') return jsonResp({'zonas': [{'clave': 'popayan', 'nombre': 'Popayán'}, {'clave': 'cali', 'nombre': 'Cali'}]});
  if (p == '/api/auth/register') return jsonResp({'token': 'tk', 'refreshToken': 'rt', 'id': 'u9', 'nombre': 'Luis', 'rol': 'conductor'});
  if (p == '/api/drivers/driver-photo') return jsonResp({'fotoConductor': '/f.png'});
  if (p == '/api/drivers/verification/vehiculo') return jsonResp({'fotoVehiculo': '/v.png'});
  if (p == '/api/auth/google') {
    return jsonResp({
      'message': 'No tienes cuenta',
      'code': 'CUENTA_NO_EXISTE',
      'google': {'nombre': 'Ana', 'apellido': 'Pérez', 'email': 'ana@gmail.com', 'foto': null},
    }, 404);
  }
  return jsonResp({});
}

Future<void> _abrir(WidgetTester tester, {Map<String, dynamic>? google, String? idToken}) async {
  pantallaAlta(tester);
  await tester.pumpWidget(MaterialApp(
    home: RegistroConductorScreen(
      google: google,
      idToken: idToken,
      obtenerIdToken: () async => _idToken,
      elegirFoto: (_) async => _png,
    ),
  ));
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

/// Pasos comunes a los dos métodos, desde la edad hasta "Crear mi cuenta".
Future<void> _desdeEdadHastaEnviar(WidgetTester tester) async {
  await _escribir(tester, 'edad', '30');
  await _escribir(tester, 'cedula', '123456');

  // Foto del conductor: obligatoria, con vista previa.
  expect(find.text('Ahora necesitamos conocerte'), findsOneWidget);
  await _siguiente(tester);
  expect(find.text('Sube una foto tuya para continuar'), findsOneWidget);
  await tester.tap(find.byKey(const Key('btn_galeria')));
  await avanzar(tester, 0.5);
  expect(find.byKey(const Key('foto_previa')), findsOneWidget);
  await _siguiente(tester);

  expect(find.text('Cuéntanos sobre tu vehículo'), findsOneWidget);
  await _escribir(tester, 'modelo', 'Chevrolet NHR 2018');

  await tester.tap(find.byKey(const Key('tipo_Camioneta')));
  await tester.pump();
  await _escribir(tester, 'capacidad', '500 kg');

  await _escribir(tester, 'placa', 'abc123');

  await tester.tap(find.byKey(const Key('btn_camara')));
  await avanzar(tester, 0.5);
  await _siguiente(tester);

  expect(find.text('¿En qué zona vas a trabajar?'), findsOneWidget);
  await avanzar(tester, 0.5);
  await tester.tap(find.byKey(const Key('zona_popayan')));
  await tester.pump();
  expect(find.text('Crear mi cuenta'), findsOneWidget);
  await _siguiente(tester);
  await avanzar(tester, 1);
}

Future<void> _limpiar(WidgetTester tester) async {
  SessionMonitorService.instance.stop();
  SocketServiceClient.instance.disconnect();
  await ApiClient.instance.clearTokens();
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 30));
}

void main() {
  testWidgets('con correo: una pregunta por pantalla, contraseñas iguales, fotos y un solo POST /api/auth/register', (tester) async {
    final log = <http.Request>[];
    await conApiFalsa(_backend, () async {
      await _abrir(tester);
      expect(find.text('Bienvenido, conductor'), findsOneWidget);
      expect(find.text('Continuar con Google'), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn_registro_correo')));
      await avanzar(tester, 0.5);
      expect(find.text('Antes de comenzar'), findsOneWidget);
      expect(find.text('Aceptar y continuar'), findsOneWidget);
      await _siguiente(tester);

      // Vacío: no avanza y muestra el error.
      await _siguiente(tester);
      expect(find.text('Este campo es obligatorio'), findsOneWidget);
      await _escribir(tester, 'nombre', 'Luis');
      await _escribir(tester, 'apellido', 'Pérez');

      // Atrás conserva lo escrito.
      await tester.tap(find.byKey(const Key('btn_atras')));
      await avanzar(tester, 0.5);
      expect(tester.widget<TextField>(find.byKey(const Key('campo_apellido'))).controller?.text, 'Pérez');
      await _siguiente(tester);

      await _escribir(tester, 'telefono', '3001234567');
      await _escribir(tester, 'email', 'luis@test.com');
      await _escribir(tester, 'password', 'secreta123');
      // Confirmación distinta: no avanza.
      await _escribir(tester, 'password2', 'otra12345');
      expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
      expect(find.byKey(const Key('campo_password2')), findsOneWidget);
      await _escribir(tester, 'password2', 'secreta123');

      await _desdeEdadHastaEnviar(tester);
      expect(find.text('Registro completado'), findsOneWidget);
      expect(find.byKey(const Key('btn_ir_panel')), findsOneWidget);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(claveBorradorRegistroConductor), isNull, reason: 'el borrador se borra al terminar');
      await _limpiar(tester);
    }, log: log);

    final registros = log.where((r) => r.url.path == '/api/auth/register').toList();
    expect(registros, hasLength(1));
    expect(jsonDecode(registros.single.body), {
      'nombre': 'Luis',
      'apellido': 'Pérez',
      'email': 'luis@test.com',
      'password': 'secreta123',
      'rol': 'conductor',
      'edad': 30,
      'telefono': '3001234567',
      'cedula': '123456',
      'placa': 'ABC123',
      'tipoVehiculo': 'Camioneta',
      'capacidad': '500 kg',
      'ciudad': 'popayan',
      'modeloVehiculo': 'Chevrolet NHR 2018',
      'aceptaTerminos': true,
    });
    // Las fotos se suben después del alta, con la sesión nueva.
    final fotos = log.where((r) => r.url.path.startsWith('/api/drivers/')).map((r) => r.url.path).toList();
    expect(fotos, ['/api/drivers/driver-photo', '/api/drivers/verification/vehiculo']);
    expect(log.firstWhere((r) => r.url.path == '/api/drivers/driver-photo').headers['Authorization'], 'Bearer tk');
  });

  testWidgets('con Google (404 CUENTA_NO_EXISTE): no vuelve a pedir nombre, apellido ni correo y manda idToken sin contraseña', (tester) async {
    final log = <http.Request>[];
    await conApiFalsa(_backend, () async {
      await _abrir(tester);
      await tester.tap(find.byKey(const Key('btn_google')));
      await avanzar(tester, 0.5);
      expect(find.text('Antes de comenzar'), findsOneWidget);
      await _siguiente(tester);

      // Resumen editable con los datos de Google; el correo no se cambia.
      expect(find.text('Confirma tus datos'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const Key('campo_nombre'))).controller?.text, 'Ana');
      expect(tester.widget<TextField>(find.byKey(const Key('campo_email'))).enabled, isFalse);
      await _siguiente(tester);

      await _escribir(tester, 'telefono', '3001234567');
      // Sin pantallas de correo ni contraseña.
      expect(find.byKey(const Key('campo_password')), findsNothing);
      await _desdeEdadHastaEnviar(tester);
      expect(find.text('Registro completado'), findsOneWidget);
      await _limpiar(tester);
    }, log: log);

    final body = jsonDecode(log.singleWhere((r) => r.url.path == '/api/auth/register').body) as Map<String, dynamic>;
    expect(body['idToken'], _idToken);
    expect(body.containsKey('password'), isFalse);
    expect(body['email'], 'ana@gmail.com');
    expect(body['nombre'], 'Ana');
    expect(body['apellido'], 'Pérez');
    expect(body['rol'], 'conductor');
  });

  testWidgets('placa duplicada (409): vuelve al paso de la placa con el mensaje del servidor, sin perder lo demás', (tester) async {
    var intentos = 0;
    await conApiFalsa((req) {
      if (req.url.path == '/api/auth/register' && intentos++ == 0) {
        return errorResp(409, 'La placa ya está registrada', 'PLACA_DUPLICADA');
      }
      return _backend(req);
    }, () async {
      await _abrir(tester);
      await tester.tap(find.byKey(const Key('btn_registro_correo')));
      await avanzar(tester, 0.5);
      await _siguiente(tester);
      for (final (paso, texto) in [('nombre', 'Luis'), ('apellido', 'Pérez'), ('telefono', '3001234567'), ('email', 'luis@test.com'), ('password', 'secreta123'), ('password2', 'secreta123')]) {
        await _escribir(tester, paso, texto);
      }
      await _desdeEdadHastaEnviar(tester);

      expect(find.byKey(const Key('campo_placa')), findsOneWidget);
      expect(find.text('La placa ya está registrada'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const Key('campo_placa'))).controller?.text, 'abc123');

      // Corrige la placa y sigue hasta el final sin volver a subir fotos ni elegir zona.
      await _escribir(tester, 'placa', 'xyz789');
      await _siguiente(tester); // foto del vehículo ya elegida
      await _siguiente(tester); // zona ya elegida
      await avanzar(tester, 1);
      expect(find.text('Registro completado'), findsOneWidget);
      await _limpiar(tester);
    });
    expect(intentos, 2);
  });

  testWidgets('borrador guardado: "Continúa tu registro" y salta al primer paso incompleto', (tester) async {
    await conApiFalsa(_backend, () async {
      SharedPreferences.setMockInitialValues({
        claveBorradorRegistroConductor: jsonEncode({
          'metodo': 'google',
          'paso': 'edad',
          'campos': {'nombre': 'Ana', 'apellido': 'Pérez', 'telefono': '3001234567', 'email': 'ana@gmail.com', 'edad': '30'},
          'google': {'nombre': 'Ana', 'apellido': 'Pérez', 'email': 'ana@gmail.com'},
        }),
      });
      await _abrir(tester);
      expect(find.text('Continúa tu registro'), findsOneWidget);
      expect(find.byKey(const Key('btn_atras')), findsNothing);

      await tester.tap(find.byKey(const Key('btn_continuar_registro')));
      await avanzar(tester, 0.5);
      // Nombre, teléfono y edad ya estaban: sigue en la cédula.
      expect(find.byKey(const Key('campo_cedula')), findsOneWidget);
      await tester.tap(find.byKey(const Key('btn_atras')));
      await avanzar(tester, 0.5);
      expect(tester.widget<TextField>(find.byKey(const Key('campo_edad'))).controller?.text, '30');
    });
  });

  testWidgets('"Empezar de nuevo" borra el borrador y vuelve a la bienvenida', (tester) async {
    await conApiFalsa(_backend, () async {
      SharedPreferences.setMockInitialValues({
        claveBorradorRegistroConductor: jsonEncode({'metodo': 'correo', 'paso': 'telefono', 'campos': {'nombre': 'Luis', 'apellido': 'P'}}),
      });
      await _abrir(tester);
      await tester.tap(find.byKey(const Key('btn_empezar_de_nuevo')));
      await avanzar(tester, 0.5);
      expect(find.text('Bienvenido, conductor'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(claveBorradorRegistroConductor), isNull);
    });
  });

  testWidgets('al avanzar se guarda un borrador sin contraseña', (tester) async {
    await conApiFalsa(_backend, () async {
      await _abrir(tester);
      await tester.tap(find.byKey(const Key('btn_registro_correo')));
      await avanzar(tester, 0.5);
      await _siguiente(tester);
      await _escribir(tester, 'nombre', 'Luis');
      await _escribir(tester, 'apellido', 'Pérez');
      await _escribir(tester, 'telefono', '3001234567');
      await _escribir(tester, 'email', 'luis@test.com');
      await _escribir(tester, 'password', 'secreta123');

      final prefs = await SharedPreferences.getInstance();
      final b = jsonDecode(prefs.getString(claveBorradorRegistroConductor)!) as Map<String, dynamic>;
      expect(b['metodo'], 'correo');
      expect(b['paso'], 'password2');
      expect(b['campos']['email'], 'luis@test.com');
      expect(jsonEncode(b).contains('secreta123'), isFalse);
    });
  });
}
