import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cargaexpress/core/environment.dart';
import 'package:cargaexpress/services/api_client.dart';
import 'package:cargaexpress/services/auth_response.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // El binding de test bloquea el HTTP real; restaurarlo para poder usar el
  // servidor embebido (mismo approach que integration_test).
  HttpOverrides.global = null;

  group('AuthResponse.fromJson', () {
    test('parses full login/register response', () {
      final auth = AuthResponse.fromJson({
        'token': 'jwt_token',
        'refreshToken': 'jwt_refresh',
        'id': 'user_1',
        'nombre': 'Carlos',
        'apellido': 'Mendoza',
        'email': 'carlos@email.com',
        'rol': 'conductor',
      });

      expect(auth.token, 'jwt_token');
      expect(auth.refreshToken, 'jwt_refresh');
      expect(auth.id, 'user_1');
      expect(auth.nombre, 'Carlos');
      expect(auth.rol, 'conductor');
    });

    test('parses refresh-token response that only contains tokens', () {
      final auth = AuthResponse.fromJson({
        'token': 'new_jwt_access_token',
        'refreshToken': 'new_jwt_refresh_token',
      });

      expect(auth.token, 'new_jwt_access_token');
      expect(auth.refreshToken, 'new_jwt_refresh_token');
      expect(auth.id, isNull);
      expect(auth.nombre, isNull);
      expect(auth.rol, isNull);
    });

    test('tolerates missing refreshToken', () {
      final auth = AuthResponse.fromJson({'token': 'solo_token'});
      expect(auth.token, 'solo_token');
      expect(auth.refreshToken, isNull);
    });
  });

  group('ApiClient refresh token con servidor local', () {
    late HttpServer server;

    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      Environment.testBaseUrl = 'http://localhost:3333';

      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 3333);
      server.listen((request) async {
        final path = request.uri.path;
        final method = request.method;

        Future<void> respond(Map<String, dynamic> body) async {
          request.response.statusCode = 200;
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode(body));
          await request.response.close();
        }

        if (method == 'POST' && path == '/api/auth/login') {
          // Login devuelve perfil completo + tokens.
          await respond({
            'token': 'access_token_login',
            'refreshToken': 'refresh_token_login',
            'id': 'cliente_id_001',
            'nombre': 'Cliente',
            'apellido': 'Test',
            'email': 'cliente@test.com',
            'rol': 'cliente',
          });
        } else if (method == 'POST' && path == '/api/auth/refresh-token') {
          // Contrato real del backend: SOLO tokens, sin perfil.
          await respond({
            'token': 'new_access_token',
            'refreshToken': 'new_refresh_token',
          });
        } else {
          request.response.statusCode = 404;
          await request.response.close();
        }
      });
    });

    tearDownAll(() async {
      Environment.testBaseUrl = null;
      await server.close(force: true);
    });

    test('refresh conserva el perfil cuando la respuesta solo trae tokens',
        () async {
      final client = ApiClient.instance;
      await client.clearTokens();

      final auth = await client.login('cliente@test.com', '123456');
      expect(auth.id, 'cliente_id_001');
      expect(client.userId, 'cliente_id_001');
      expect(client.rol, 'cliente');

      final refreshed = await client.refreshToken();
      expect(refreshed.token, 'new_access_token');
      expect(client.token, 'new_access_token');
      // El perfil en memoria NO debe perderse.
      expect(client.userId, 'cliente_id_001');
      expect(client.rol, 'cliente');
      expect(client.email, 'cliente@test.com');
    });
  });
}