import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:cargaexpress/screens/cliente/home_screen.dart';
import 'package:cargaexpress/screens/user/google_login.dart';
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

void main() {
  final idToken = 'x' * 40;

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

  testWidgets('cuenta nueva pide teléfono y edad y luego abre el inicio', (tester) async {
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
      if (req.url.path == '/api/trips/active') return errorResp(404, 'Sin viaje');
      return jsonResp({'data': []});
    }, () async {
      await tester.pumpWidget(_boton(() async => idToken));
      await tester.tap(find.byKey(const Key('btn_google')));
      await avanzar(tester);
      expect(find.byType(CompletarPerfilScreen), findsOneWidget);
      final google = log.firstWhere((r) => r.url.path == '/api/auth/google');
      expect(jsonDecode(google.body), {'idToken': idToken});

      // Menor de edad: no se envía nada.
      await tester.enterText(find.byKey(const Key('campo_telefono_google')), '3001234567');
      await tester.enterText(find.byKey(const Key('campo_edad_google')), '16');
      await tester.tap(find.byKey(const Key('btn_completar_perfil')));
      await avanzar(tester);
      expect(log.where((r) => r.method == 'PUT'), isEmpty);

      await tester.enterText(find.byKey(const Key('campo_edad_google')), '30');
      await tester.tap(find.byKey(const Key('btn_completar_perfil')));
      await avanzar(tester);
      final put = log.firstWhere((r) => r.method == 'PUT');
      expect(jsonDecode(put.body), {'telefono': '3001234567', 'edad': 30});
      expect(find.byType(ClienteHomeScreen), findsOneWidget);
      await _limpiar(tester);
    }, log: log);
  });
}
