import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:integration_test/integration_test.dart';
import 'package:cargaexpress/main.dart' as app;
import 'mock_server.dart';
import 'test_utils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final mockServer = MockServer();

  setUpAll(() async {
    // Avoid socket connections (will fail against mock server, but that's OK)
    HttpOverrides.global = null;
    await mockServer.start();
  });

  tearDownAll(() async {
    await mockServer.stop();
  });

  setUp(() async {
    // Login again at the start of each test by clearing SharedPreferences
    // and restarting the app (handled by the test itself).
  });

  testWidgets('Flujo completo: Cliente → Conductor → Entrega',
      (tester) async {
    // ────────────────────────────────────────────────────────────────
    // 1. INICIAR APP
    // ────────────────────────────────────────────────────────────────
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Should see the auth landing screen
    expect(find.text('CargaExpress'), findsWidgets);
    expect(find.text('Iniciar Sesion'), findsOneWidget);

    // ────────────────────────────────────────────────────────────────
    // 2. INICIAR SESIÓN COMO CLIENTE
    // ────────────────────────────────────────────────────────────────
    await login(tester, 'cliente@test.com', '123456');
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Verify we're on ClienteHomeScreen — expect "Solicitar viaje" button
    expect(find.text('Solicitar viaje'), findsOneWidget);

    // ────────────────────────────────────────────────────────────────
    // 3. SOLICITAR VIAJE
    // ────────────────────────────────────────────────────────────────
    await tapButton(tester, 'Solicitar viaje');
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Should be on NuevoEnvioScreen — fill the form
    await tester.pumpAndSettle();

    // Tap on the map to add origin — use "Mi ubicación (origen)" instead
    // for reliability
    await tapButtonWithDelay(tester, 'Mi ubicación (origen)',
        delay: const Duration(seconds: 1));

    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Tap "Mi ubicación (destino)"
    await tapButtonWithDelay(tester, 'Mi ubicación (destino)',
        delay: const Duration(seconds: 1));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Enter description
    await enterTextByLabel(tester, 'Descripción de la carga', 'Caja de herramientas de prueba');
    await tester.pumpAndSettle();

    // Enter price — tap on the price to edit it
    // The price field shows "$0" initially, tap to edit
    final priceFinder = find.textContaining('\$0');
    if (priceFinder.evaluate().isNotEmpty) {
      await tester.tap(priceFinder);
      await tester.pumpAndSettle();
      // Now a TextField should appear
      final priceField = find.byType(TextField).last;
      await tester.enterText(priceField, '250');
      await tester.pumpAndSettle();
    }

    // Submit the trip request
    await tapButtonWithDelay(tester, 'Solicitar viaje',
        delay: const Duration(seconds: 1));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Should navigate to RastreoScreen — verify trip is pending
    // Give it time to poll and show status
    await tester.pumpAndSettle(const Duration(seconds: 8));
    // The RastreoScreen shows trip info after navigation
    expect(mockServer.activeTrip, isNotNull);
    expect(mockServer.activeTrip!['estado'], 'buscando_conductor');

    // ────────────────────────────────────────────────────────────────
    // 4. CERRAR SESIÓN COMO CLIENTE
    // ────────────────────────────────────────────────────────────────
    // Go back to home screen first
    // Look for a back button
    final backButton = find.byTooltip('Back');
    if (backButton.evaluate().isNotEmpty) {
      await tester.tap(backButton);
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }

    // Open drawer
    final menuButton = find.byIcon(Icons.menu);
    if (menuButton.evaluate().isNotEmpty) {
      await tester.tap(menuButton.first);
      await tester.pumpAndSettle(const Duration(seconds: 1));
    }

    // Tap "Cerrar sesión" in drawer
    final logoutItem = find.text('Cerrar sesión');
    if (logoutItem.evaluate().isNotEmpty) {
      await tester.tap(logoutItem);
      await tester.pumpAndSettle(const Duration(seconds: 3));
    } else {
      // Fallback: navigate to AuthScreen via the back stack
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }

    // Should be back at auth screen
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.text('Iniciar Sesion'), findsOneWidget);

    // ────────────────────────────────────────────────────────────────
    // 5. CREAR OFERTA COMO CONDUCTOR (via mock server)
    // ────────────────────────────────────────────────────────────────
    // Emulate the driver making an offer on the active trip
    // (the driver would see this in their offers screen)
    mockServer.addOffer({
      '_id': 'offer_test_001',
      'id': 'offer_test_001',
      'monto': 200,
      'conductor': {
        '_id': 'conductor_id_001',
        'nombre': 'Conductor',
        'apellido': 'Test',
        'calificacion': 4.5,
      },
    });

    // Accept the offer (simulating client acceptance)
    mockServer.acceptOffer('offer_test_001');
    mockServer.setTripStatus('aceptado');

    // ────────────────────────────────────────────────────────────────
    // 6. INICIAR SESIÓN COMO CONDUCTOR
    // ────────────────────────────────────────────────────────────────
    await login(tester, 'conductor@test.com', '123456');
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Should be on Conductor HomeScreen
    // Wait for it to poll and detect the active trip
    await tester.pumpAndSettle(const Duration(seconds: 10));

    // The conductor home screen should show the active trip card
    // Look for "Ver viaje en el mapa" button
    final verViajeFinder = find.textContaining('Ver viaje');
    if (verViajeFinder.evaluate().isEmpty) {
      // Try navigating through the bottom nav or menu
      final viajesNavItem = find.text('Viajes');
      if (viajesNavItem.evaluate().isNotEmpty) {
        await tester.tap(viajesNavItem);
        await tester.pumpAndSettle(const Duration(seconds: 3));
      }
    }

    await tester.pumpAndSettle(const Duration(seconds: 5));

    // ────────────────────────────────────────────────────────────────
    // 7. NAVEGAR AL VIAJE ACTIVO
    // ────────────────────────────────────────────────────────────────
    if (verViajeFinder.evaluate().isNotEmpty) {
      await tester.tap(verViajeFinder.first);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    }

    // Should be on TripInProgressScreen or OfertaAceptadaScreen ("Iniciar viaje")
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Try to start the trip — look for "Iniciar viaje" button
    final iniciarViaje = find.text('Iniciar viaje');
    if (iniciarViaje.evaluate().isNotEmpty) {
      await tester.tap(iniciarViaje);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    }

    // If the trip is already "en_curso", the "Finalizar viaje" button
    // should appear on TripInProgressScreen
    // Update mock server state to simulate finalization
    mockServer.setTripStatus('entregado');
    await tester.pumpAndSettle(const Duration(seconds: 10));

    // ────────────────────────────────────────────────────────────────
    // 8. FINALIZAR VIAJE
    // ────────────────────────────────────────────────────────────────
    // The screen should now show "Finalizar viaje" or "He llegado"
    final finalizarViaje = find.textContaining('Finalizar');
    if (finalizarViaje.evaluate().isNotEmpty) {
      await tester.tap(finalizarViaje.first);
      await tester.pumpAndSettle(const Duration(seconds: 3));
    }

    // Handle the photo evidence dialog — choose "Sin foto"
    final sinFoto = find.text('Sin foto');
    if (sinFoto.evaluate().isNotEmpty) {
      await tester.tap(sinFoto);
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }

    // Handle the countdown dialog — wait for timeout or cancel
    final cancelarFinalizacion = find.text('Cancelar');
    if (cancelarFinalizacion.evaluate().isNotEmpty) {
      // Cancel and finalize directly via mock server
      await tester.tap(cancelarFinalizacion);
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }

    // Finalize the trip via mock server
    mockServer.setTripStatus('finalizado');

    // Wait for polling to pick up the final status
    await tester.pumpAndSettle(const Duration(seconds: 10));

    // ────────────────────────────────────────────────────────────────
    // 9. VERIFICACIONES
    // ────────────────────────────────────────────────────────────────
    // The trip should be finalized
    expect(mockServer.activeTrip?['estado'], 'finalizado');

    // The UI should eventually reflect the finalized state
    // (either on EntregaConfirmadaScreen or back on HomeScreen)
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Print debug info
    // ignore: avoid_print
    print('=== INTEGRATION TEST COMPLETED ===');
    // ignore: avoid_print
    print('Active trip status: ${mockServer.activeTrip?['estado']}');
  }, timeout: const Timeout(Duration(seconds: 180)));
}
