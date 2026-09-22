import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cargaexpress/core/environment.dart';
import 'package:cargaexpress/services/api/coverage_service.dart';
import 'package:cargaexpress/services/api/http_client.dart';
import 'package:cargaexpress/services/api_client.dart';
import 'package:cargaexpress/services/session_events.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  group('HttpClient sesión / suspensión / errores', () {
    late HttpServer server;
    var refreshStatus = 200;
    Map<String, dynamic>? lastLogoutBody;

    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      Environment.testBaseUrl = 'http://localhost:${server.port}';

      server.listen((request) async {
        final path = request.uri.path;
        Future<void> respond(int status, Object body, {bool json = true}) async {
          request.response.statusCode = status;
          if (json) request.response.headers.contentType = ContentType.json;
          request.response.write(json ? jsonEncode(body) : body);
          await request.response.close();
        }

        if (path == '/api/auth/login') {
          await respond(200, {
            'token': 'access_1',
            'refreshToken': 'refresh_1',
            'id': 'u1',
            'rol': 'cliente',
          });
        } else if (path == '/api/auth/refresh-token') {
          if (refreshStatus == 200) {
            await respond(200, {'token': 'access_2', 'refreshToken': 'refresh_2'});
          } else {
            await respond(refreshStatus, {'error': 'fallo'});
          }
        } else if (path == '/api/auth/logout') {
          final raw = await utf8.decoder.bind(request).join();
          lastLogoutBody = jsonDecode(raw) as Map<String, dynamic>;
          await respond(200, {'message': 'Sesión cerrada'});
        } else if (path == '/api/expired') {
          await respond(401, {'error': 'Token expirado'});
        } else if (path == '/api/suspended') {
          await respond(403, {
            'code': 'CUENTA_SUSPENDIDA',
            'errors': [
              {'message': 'Tu cuenta está suspendida'}
            ],
          });
        } else if (path == '/api/html') {
          await respond(502, '<html>Bad gateway</html>', json: false);
        } else if (path == '/api/weird') {
          await respond(400, {'error': 123});
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

    setUp(() async {
      refreshStatus = 200;
      await ApiClient.instance.clearTokens();
      await ApiClient.instance.login('c@test.com', '123456');
    });

    test('refresh con 503 conserva la sesión y relanza', () async {
      refreshStatus = 503;
      await expectLater(
        HttpClient.get('/api/expired', auth: true),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 503)),
      );
      expect(ApiClient.instance.token, 'access_1');
    });

    test('refresh con 429 conserva la sesión', () async {
      refreshStatus = 429;
      await expectLater(HttpClient.get('/api/expired', auth: true), throwsA(isA<ApiException>()));
      expect(ApiClient.instance.token, 'access_1');
    });

    test('refresh con 401 limpia la sesión y emite expired', () async {
      refreshStatus = 401;
      final events = <SessionEvent>[];
      final sub = SessionEvents.instance.stream.listen(events.add);
      await expectLater(
        HttpClient.get('/api/expired', auth: true),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
      );
      await Future<void>.delayed(Duration.zero);
      expect(ApiClient.instance.token, isNull);
      expect(events.map((e) => e.type), contains(SessionEventType.expired));
      await sub.cancel();
    });

    test('403 CUENTA_SUSPENDIDA limpia la sesión y emite suspended', () async {
      final completer = Completer<SessionEvent>();
      final sub = SessionEvents.instance.stream.listen((e) {
        if (!completer.isCompleted) completer.complete(e);
      });
      await expectLater(
        HttpClient.get('/api/suspended', auth: true),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', 'CUENTA_SUSPENDIDA')
            .having((e) => e.message, 'message', 'Tu cuenta está suspendida')),
      );
      final event = await completer.future.timeout(const Duration(seconds: 2));
      expect(event.type, SessionEventType.suspended);
      expect(event.message, 'Tu cuenta está suspendida');
      expect(ApiClient.instance.token, isNull);
      await sub.cancel();
    });

    test('cuerpo no JSON produce mensaje legible con el código', () async {
      await expectLater(
        HttpClient.get('/api/html', auth: true),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'status', 502)
            .having((e) => e.message, 'message', contains('502'))),
      );
    });

    test('error no string se convierte a texto', () async {
      await expectLater(
        HttpClient.get('/api/weird', auth: true),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', '123')),
      );
    });

    test('logout envía el refresh token y limpia la sesión', () async {
      lastLogoutBody = null;
      await ApiClient.instance.logout();
      expect(lastLogoutBody, {'refreshToken': 'refresh_1'});
      expect(ApiClient.instance.token, isNull);
    });

    test('upload rechaza archivos mayores al límite sin llamar al backend', () async {
      await expectLater(
        HttpClient.uploadFile(
          '/api/users/avatar',
          bytes: List<int>.filled(HttpClient.defaultMaxUploadBytes + 1, 0),
          filename: 'a.jpg',
          fieldName: 'file',
          auth: true,
        ),
        throwsA(isA<ApiException>().having(
            (e) => e.message, 'message', 'La imagen supera 5 MB. Intenta con otra foto.')),
      );
    });
  });

  group('helpers puros', () {
    test('extractError tolera formatos', () {
      expect(HttpClient.extractError({'message': 'm'}), 'm');
      expect(HttpClient.extractError({'errors': [{'message': 'e'}]}), 'e');
      expect(HttpClient.extractError({'errors': ['x']}), 'x');
      expect(HttpClient.extractError({'error': 'err'}), 'err');
      expect(HttpClient.extractError(null, 500), contains('500'));
    });

    test('mediaTypeForFilename', () {
      expect(HttpClient.mediaTypeForFilename('a.JPG').mimeType, 'image/jpeg');
      expect(HttpClient.mediaTypeForFilename('a.png').mimeType, 'image/png');
      expect(HttpClient.mediaTypeForFilename('a.webp').mimeType, 'image/webp');
      expect(HttpClient.mediaTypeForFilename('a.pdf').mimeType, 'application/pdf');
      expect(HttpClient.mediaTypeForFilename('a').mimeType, 'application/octet-stream');
    });

    test('isInsideCoverage con rectángulos y círculo', () {
      final zonas = [
        {'clave': 'cali', 'nombre': 'Cali', 'norte': 3.55, 'sur': 3.30, 'este': -76.45, 'oeste': -76.60},
        {'clave': 'pop', 'nombre': 'Popayán', 'lat': 2.44, 'lng': -76.61, 'radio': 10},
      ];
      expect(isInsideCoverage(zonas, 3.45, -76.53), isTrue); // Cali
      expect(isInsideCoverage(zonas, 2.45, -76.60), isTrue); // Popayán (círculo)
      expect(isInsideCoverage(zonas, 4.71, -74.07), isFalse); // Bogotá
      expect(isInsideCoverage(const [], 4.71, -74.07), isTrue); // sin zonas
    });
  });
}
