import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cargaexpress/screens/shared/eliminar_cuenta.dart';

import '../../helpers/fake_api.dart';

void main() {
  Future<void> abrirDialogo(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => mostrarDialogoEliminarCuenta(context),
            child: const Text('abrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await avanzar(tester);
  }

  testWidgets('sin escribir ELIMINAR: error y no llama al servidor', (tester) async {
    final log = <dynamic>[];
    await conApiFalsa((req) {
      log.add(req);
      return jsonResp({});
    }, () async {
      await abrirDialogo(tester);
      await tester.enterText(find.byKey(const Key('campo_eliminar_cuenta')), 'borrar');
      await tester.tap(find.text('Eliminar cuenta'));
      await avanzar(tester);

      expect(find.text('Escribe ELIMINAR para confirmar'), findsOneWidget);
      expect(log, isEmpty);
    });
  });

  testWidgets('409 del servidor: muestra el motivo sin cerrar', (tester) async {
    await conApiFalsa((req) {
      if (req.method == 'DELETE' && req.url.path == '/api/users/me') {
        return errorResp(409, 'Tienes un viaje activo. Termínalo antes de eliminar tu cuenta.');
      }
      return jsonResp({});
    }, () async {
      await abrirDialogo(tester);
      await tester.enterText(find.byKey(const Key('campo_eliminar_cuenta')), 'eliminar');
      await tester.tap(find.text('Eliminar cuenta'));
      await avanzar(tester);

      expect(find.text('Tienes un viaje activo. Termínalo antes de eliminar tu cuenta.'), findsOneWidget);
      expect(find.text('¿Eliminar tu cuenta?'), findsOneWidget);
    });
  });
}
