import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:cargaexpress/screens/user/recuperar_password_screen.dart';

import '../helpers/fake_api.dart';

void main() {
  testWidgets('envía el código, valida y cambia la contraseña', (tester) async {
    pantallaAlta(tester);
    final log = <http.Request>[];
    bool? resultado;
    await conApiFalsa(
      (req) => req.url.path.endsWith('reset-password') && (jsonDecode(req.body) as Map)['codigo'] == '000000'
          ? errorResp(400, 'Código inválido o vencido')
          : jsonResp({'message': 'ok'}),
      () async {
        await tester.pumpWidget(MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => resultado = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const RecuperarPasswordScreen(email: 'ana@correo.co')),
              ),
              child: const Text('abrir'),
            ),
          ),
        ));
        await tester.tap(find.text('abrir'));
        await avanzar(tester);

        await tester.tap(find.byKey(const Key('btn_recuperar')));
        await avanzar(tester);
        expect(find.byKey(const Key('campo_recuperar_codigo')), findsOneWidget);

        // Validación local antes de llamar al servidor.
        await tester.enterText(find.byKey(const Key('campo_recuperar_codigo')), '123');
        await tester.tap(find.byKey(const Key('btn_recuperar')));
        await avanzar(tester);
        expect(find.text('El código tiene 6 dígitos'), findsOneWidget);

        // Error del servidor: se queda en la pantalla.
        await tester.enterText(find.byKey(const Key('campo_recuperar_codigo')), '000000');
        await tester.enterText(find.byKey(const Key('campo_recuperar_nueva')), 'Nueva1234');
        await tester.enterText(find.byKey(const Key('campo_recuperar_confirmar')), 'Nueva1234');
        await tester.tap(find.byKey(const Key('btn_recuperar')));
        await avanzar(tester);
        expect(find.text('Código inválido o vencido'), findsOneWidget);

        await tester.enterText(find.byKey(const Key('campo_recuperar_codigo')), '654321');
        await tester.tap(find.byKey(const Key('btn_recuperar')));
        await avanzar(tester);
        expect(resultado, isTrue);
      },
      log: log,
    );
    expect(log.first.url.path, '/api/auth/forgot-password');
    expect(jsonDecode(log.first.body), {'email': 'ana@correo.co'});
    expect(jsonDecode(log.last.body), {'email': 'ana@correo.co', 'codigo': '654321', 'password': 'Nueva1234'});
  });
}
