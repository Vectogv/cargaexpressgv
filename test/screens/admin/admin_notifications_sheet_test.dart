import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cargaexpress/screens/admin/admin_common.dart';

void main() {
  testWidgets('la campana de admin abre la lista de notificaciones', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => showAdminNotificationsSheet(context),
          ),
        ),
      ),
    ));

    await tester.tap(find.byIcon(Icons.notifications_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Notificaciones'), findsOneWidget);
    expect(find.text('Sin notificaciones'), findsOneWidget);
  });
}
