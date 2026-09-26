import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cargaexpress/screens/shared/ui_compartida.dart';
import 'package:cargaexpress/screens/user/auth_screen.dart';
import 'package:cargaexpress/screens/user/auth_estilos.dart';

void main() {
  testWidgets('FondoDegradado pinta un color sólido debajo del degradado', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: FondoDegradado(colores: [Color(0xFF2563EB), Color(0xFF1E3A8A)], child: SizedBox(height: 40)),
    ));
    final solido = tester.widget<DecoratedBox>(find.byKey(const Key('fondo_degradado_solido')));
    final decoracion = solido.decoration as BoxDecoration;
    expect(decoracion.color, const Color(0xFF2563EB));
    expect(decoracion.gradient, isNull);
    // Y encima el degradado con los mismos colores.
    final conDegradado = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((d) => d.decoration)
        .whereType<BoxDecoration>()
        .where((d) => d.gradient != null);
    expect(conDegradado, isNotEmpty);
    expect((conDegradado.first.gradient as LinearGradient).colors, [const Color(0xFF2563EB), const Color(0xFF1E3A8A)]);
  });

  testWidgets('la cabecera de la bienvenida tiene el azul explícito (no depende del tema)', (tester) async {
    tester.view.physicalSize = const Size(1440, 2880);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.black), useMaterial3: true),
      home: const AuthScreen(),
    ));
    final cabecera = find.byKey(const Key('cabecera_bienvenida'));
    expect(cabecera, findsOneWidget);
    final solido = tester.widget<DecoratedBox>(find.descendant(of: cabecera, matching: find.byKey(const Key('fondo_degradado_solido'))));
    expect((solido.decoration as BoxDecoration).color, AuthColores.primario);
    expect(find.text('Envía tu carga sin complicaciones'), findsOneWidget);
  });

  testWidgets('BotonPrincipal cargando se deshabilita y muestra el progreso', (tester) async {
    var toques = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(children: [
          BotonPrincipal(texto: 'Continuar', icono: Icons.check, onPressed: () => toques++),
          BotonPrincipal(texto: 'Continuar', cargando: true, onPressed: () => toques++),
          BotonSecundario(texto: 'Cancelar', onPressed: () => toques++),
        ]),
      ),
    ));
    await tester.tap(find.text('Continuar'));
    await tester.tap(find.text('Cancelar'));
    expect(toques, 2);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final deshabilitado = tester.widget<FilledButton>(
      find.ancestor(of: find.byType(CircularProgressIndicator), matching: find.byType(FilledButton)),
    );
    expect(deshabilitado.onPressed, isNull);
  });

  testWidgets('BarraInferiorFija respeta el área segura inferior', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3.0;
    tester.view.padding = const FakeViewPadding(bottom: 90);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SizedBox.expand(),
        bottomNavigationBar: BarraInferiorFija(child: Text('Acción')),
      ),
    ));
    final alto = tester.view.physicalSize.height / tester.view.devicePixelRatio;
    // 90 px físicos = 30 dp de barra del sistema, más el padding de 12.
    expect(tester.getBottomLeft(find.text('Acción')).dy, lessThanOrEqualTo(alto - 30 - 12));
  });

  testWidgets('EncabezadoEstado muestra título y detalle sobre el degradado', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: EncabezadoEstado(titulo: 'Viaje aceptado', detalle: 'Ve a recoger', icono: Icons.local_shipping),
      ),
    ));
    expect(find.text('Viaje aceptado'), findsOneWidget);
    expect(find.text('Ve a recoger'), findsOneWidget);
    expect(find.byKey(const Key('fondo_degradado_solido')), findsOneWidget);
  });
}
