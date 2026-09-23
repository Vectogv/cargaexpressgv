import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Respuesta del backend falso para una petición.
typedef FakeHandler = FutureOr<http.Response> Function(http.Request req);

/// Respuesta JSON (UTF-8) con [status].
http.Response jsonResp(Object? body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

/// Error del backend con el formato habitual `{message, code}`.
http.Response errorResp(int status, [String message = 'Error del servidor', String? code]) =>
    jsonResp({'message': message, if (code != null) 'code': code}, status);

/// Ejecuta [body] con todas las llamadas de `package:http` (HttpClient de la
/// app) respondidas por [handler]. Las peticiones quedan en [log].
Future<void> conApiFalsa(
  FakeHandler handler,
  Future<void> Function() body, {
  List<http.Request>? log,
}) {
  SharedPreferences.setMockInitialValues({});
  return http.runWithClient(body, () => MockClient((req) async {
        log?.add(req);
        return handler(req);
      }));
}

/// Pantalla alta para que los botones inferiores sean visibles en el test
/// (480 dp de ancho: la fuente de test "Ahem" es más ancha que la real).
void pantallaAlta(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 2880);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

/// Avanza [segundos] en pasos de 100 ms (sirve con animaciones infinitas,
/// donde `pumpAndSettle` no termina).
Future<void> avanzar(WidgetTester tester, [double segundos = 1]) async {
  final pasos = (segundos * 10).ceil();
  for (var i = 0; i < pasos; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
