import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Finds a [TextField] by its label text and enters [value]. 
Future<void> enterTextByLabel(WidgetTester tester, String label, String value) async {
  final field = find.ancestor(
    of: find.widgetWithText(TextField, label),
    matching: find.byType(TextField),
  );
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.enterText(field, value);
  await tester.pumpAndSettle();
}

/// Taps a button with exact [text].
Future<void> tapButton(WidgetTester tester, String text) async {
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

/// Taps a button after a delay (for when dialogs need time to appear).
Future<void> tapButtonWithDelay(WidgetTester tester, String text, {Duration delay = const Duration(milliseconds: 500)}) async {
  await tester.pump(delay);
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

/// Logs in with given [email] and [password] starting from [LoginScreen].
Future<void> login(WidgetTester tester, String email, String password) async {
  // Tap "Iniciar Sesion" on the auth landing screen
  await tapButton(tester, 'Iniciar Sesion');
  await tester.pumpAndSettle();

  // Fill email
  await enterTextByLabel(tester, 'Correo electrónico', email);
  // Fill password
  await enterTextByLabel(tester, 'Contraseña', password);
  // Tap login button
  await tapButton(tester, 'Iniciar Sesión');
  await tester.pumpAndSettle(const Duration(seconds: 3));
}

/// Verifies that a snackbar with [message] is shown.
Future<void> expectSnackbar(WidgetTester tester, String message) async {
  await tester.pumpAndSettle();
  expect(find.text(message), findsOneWidget);
}
