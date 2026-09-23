import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cargaexpress/core/environment.dart';
import 'package:cargaexpress/services/api_client.dart';
import 'package:cargaexpress/services/error_handler_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // El binding de test bloquea el HTTP real; restaurarlo para el servidor embebido.
  HttpOverrides.global = null;

  group('HttpClient 401 -> refresh -> reintento', () {
    late HttpServer server;
    var refreshFails = false;
    var authExpiredEvents = 0;

    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});

      ErrorHandlerService.instance.onAuthExpired.listen((_) {
        authExpiredEvents++;
      });

      // Puerto efímero (0): evita colisiones con otra suite o un proceso
      // residual que tenga ocupado un puerto fijo.
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      Environment.testBaseUrl = 'http://127.0.0.1:${server.port}';
      server.listen((request) async {
        final path = request.uri.path;
        final method = request.method;

        Future<void> respond(int status, Map<String, dynamic> body) async {
          request.response.statusCode = status;
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode(body));
          await request.response.close();
        }

        if (method == 'POST' && path == '/api/auth/login') {
          // El login emite un token que el servidor YA considera expirado
          // (solo acepta el token post-refresh en /api/trips/history).
          await respond(200, {
            'token': 'access_token_login',
            'refreshToken': 'refresh_token_login',
            'id': 'cliente_id_001',
            'nombre': 'Cliente',
            'apellido': 'Test',
            'email': 'cliente@test.com',
            'rol': 'cliente',
          });
        } else if (method == 'POST' && path == '/api/auth/refresh-token') {
          if (refreshFails) {
            await respond(401, {'message': 'Refresh token invalido'});
          } else {
            await respond(200, {
              'token': 'access_token_refreshed',
              'refreshToken': 'refresh_token_2',
            });
          }
        } else if (method == 'GET' && path == '/api/trips/history') {
          final auth = request.headers.value('authorization');
          if (auth == 'Bearer access_token_refreshed') {
            await respond(200, {'data': <dynamic>[]});
          } else {
            await respond(401, {'message': 'Token expirado'});
          }
        } else {
          await respond(404, {'message': 'Not found'});
        }
      });
    });

    tearDownAll(() async {
      Environment.testBaseUrl = null;
      await server.close(force: true);
      await ApiClient.instance.clearTokens();
    });

    setUp(() {
      refreshFails = false;
      authExpiredEvents = 0;
    });

    test('401 dispara refresh y reintenta la petición con el token nuevo',
        () async {
      final client = ApiClient.instance;
      await client.clearTokens();

      await client.login('cliente@test.com', '123456');
      expect(client.token, 'access_token_login');

      // La primera llamada recibe 401 (token expirado) -> refresh -> reintento OK.
      final history = await client.getTripHistory();
      expect(history, isEmpty);
      expect(client.token, 'access_token_refreshed');
      expect(authExpiredEvents, 0);
    });

    test('si el refresh falla, limpia la sesión y emite sesión expirada',
        () async {
      final client = ApiClient.instance;
      await client.clearTokens();

      await client.login('cliente@test.com', '123456');
      expect(client.token, 'access_token_login');

      refreshFails = true;

      final expired = Completer<void>();
      final sub = ErrorHandlerService.instance.onAuthExpired.listen((_) {
        if (!expired.isCompleted) expired.complete();
      });

      await expectLater(
        client.getTripHistory(),
        throwsA(isA<Exception>()),
      );
      expect(client.token, isNull);

      // Esperar el evento de sesión expirada (entrega asíncrona del stream).
      await expired.future.timeout(const Duration(seconds: 2));
      await sub.cancel();
    });
  });
}