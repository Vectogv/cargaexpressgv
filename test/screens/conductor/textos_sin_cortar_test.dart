import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cargaexpress/screens/conductor/earnings_screen.dart';
import 'package:cargaexpress/screens/conductor/solicitudes_disponibles_section.dart';
import 'package:cargaexpress/screens/shared/ui_compartida.dart' show BotonSecundario;

import '../../helpers/fake_api.dart';

/// Dos cortes vistos en vivo a 360 dp de ancho: "Sem…" en los botones del PDF
/// de Ganancias y "Estás desc/onectado" en la tarjeta del inicio. Se mide con
/// la letra real de la app (la de prueba, Ahem, es cuadrada y mucho más ancha).
void main() {
  setUpAll(() async {
    final loader = FontLoader('InstrumentSans');
    for (final peso in [400, 500, 600, 700]) {
      loader.addFont(rootBundle.load('assets/fonts/InstrumentSans-$peso.ttf'));
    }
    await loader.load();
  });

  void pantalla360(WidgetTester tester) {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Widget app(Widget home) => MaterialApp(theme: ThemeData(fontFamily: 'InstrumentSans'), home: home);

  /// El texto cabe entero en una sola línea (ni elipsis ni salto).
  bool enUnaLinea(WidgetTester tester, Finder f) {
    final rp = tester.renderObject<RenderParagraph>(f);
    return rp.getMaxIntrinsicWidth(double.infinity) <= rp.size.width + 0.01;
  }

  testWidgets('Ganancias: los 3 botones del PDF se leen completos a 360 dp', (tester) async {
    pantalla360(tester);
    await conApiFalsa((_) => jsonResp({}), () async {
      await tester.pumpWidget(app(const EarningsScreen()));
      await avanzar(tester, 1);
      await tester.scrollUntilVisible(find.text('Descargar reporte en PDF'), 200);
      await tester.pump();
      for (final texto in ['Todo', 'Semana', 'Mes']) {
        final f = find.descendant(of: find.byType(BotonSecundario), matching: find.text(texto));
        expect(f, findsOneWidget);
        expect(enUnaLinea(tester, f), isTrue, reason: '"$texto" sale cortado');
      }
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('Inicio desconectado: "Estás desconectado" no se parte y "Conectarme" tiene acción', (tester) async {
    pantalla360(tester);
    var toques = 0;
    await tester.pumpWidget(app(Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SolicitudesDisponiblesSection(online: false, onConectar: () => toques++),
      ),
    )));
    await tester.pump();

    expect(enUnaLinea(tester, find.text('Estás desconectado')), isTrue);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Conectarme'));
    expect(toques, 1);
  });
}
