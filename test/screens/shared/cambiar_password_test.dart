import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cargaexpress/screens/shared/cambiar_password.dart';

import '../../helpers/fake_api.dart';

void main() {
  Future<void> abrirDialogo(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => mostrarDialogoCambiarPassword(context),
            child: const Text('abrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await avanzar(tester);
  }

  testWidgets('nueva y confirmación distintas: error sin llamar al servidor', (tester) async {
    final log = <dynamic>[];
    await conApiFalsa((req) {
      log.add(req);
      return jsonResp({'message': 'ok'});
    }, () async {
      await abrirDialogo(tester);

      await tester.enterText(find.byKey(const Key('campo_password_actual')), 'actual123');
      await tester.enterText(find.byKey(const Key('campo_password_nueva')), 'nuevaClave1');
      await tester.enterText(find.byKey(const Key('campo_password_confirmar')), 'otraClave1');
      await tester.tap(find.text('Guardar'));
      await avanzar(tester);

      expect(find.text('Las contraseñas nuevas no coinciden'), findsOneWidget);
      expect(log, isEmpty);
    });
  });

  testWidgets('nueva contraseña muy corta: error sin llamar al servidor', (tester) async {
    final log = <dynamic>[];
    await conApiFalsa((req) {
      log.add(req);
      return jsonResp({'message': 'ok'});
    }, () async {
      await abrirDialogo(tester);

      await tester.enterText(find.byKey(const Key('campo_password_actual')), 'actual123');
      await tester.enterText(find.byKey(const Key('campo_password_nueva')), 'corta1');
      await tester.enterText(find.byKey(const Key('campo_password_confirmar')), 'corta1');
      await tester.tap(find.text('Guardar'));
      await avanzar(tester);

      expect(find.text('La nueva contraseña debe tener al menos 8 caracteres'), findsOneWidget);
      expect(log, isEmpty);
    });
  });

  testWidgets('422 del servidor: muestra "La contraseña actual no es correcta" sin cerrar el diálogo', (tester) async {
    await conApiFalsa((req) {
      if (req.method == 'PUT' && req.url.path == '/api/users/password') {
        return errorResp(422, 'La contraseña actual no es correcta');
      }
      return jsonResp({});
    }, () async {
      await abrirDialogo(tester);

      await tester.enterText(find.byKey(const Key('campo_password_actual')), 'incorrecta');
      await tester.enterText(find.byKey(const Key('campo_password_nueva')), 'nuevaClave1');
      await tester.enterText(find.byKey(const Key('campo_password_confirmar')), 'nuevaClave1');
      await tester.tap(find.text('Guardar'));
      await avanzar(tester);

      expect(find.text('La contraseña actual no es correcta'), findsOneWidget);
      expect(find.text('Cambiar contraseña'), findsOneWidget);
    });
  });

  testWidgets('éxito: cierra el diálogo y muestra el SnackBar de confirmación', (tester) async {
    await conApiFalsa((req) {
      if (req.method == 'PUT' && req.url.path == '/api/users/password') {
        return jsonResp({'message': 'Contraseña actualizada'});
      }
      return jsonResp({});
    }, () async {
      await abrirDialogo(tester);

      await tester.enterText(find.byKey(const Key('campo_password_actual')), 'actual123');
      await tester.enterText(find.byKey(const Key('campo_password_nueva')), 'nuevaClave1');
      await tester.enterText(find.byKey(const Key('campo_password_confirmar')), 'nuevaClave1');
      await tester.tap(find.text('Guardar'));
      await avanzar(tester);

      expect(find.text('Cambiar contraseña'), findsNothing);
      expect(find.text('Contraseña actualizada'), findsOneWidget);
    });
  });
}
