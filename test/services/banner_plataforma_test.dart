import 'package:cargaexpress/screens/cliente/cliente_inicio_view.dart';
import 'package:cargaexpress/services/banner_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('banner con solo imagen (sin texto) es visible', () {
    final b = BannerPlataforma.fromJson({'activo': true, 'imagenUrl': '/storage/uploads/banner-1.png', 'texto': null, 'link': null});
    expect(b.visible, isTrue);
    expect(b.imagenUrl, '/storage/uploads/banner-1.png');
  });

  test('banner inactivo o vacío no se muestra', () {
    expect(BannerPlataforma.fromJson({'activo': false, 'imagenUrl': '/x.png'}).visible, isFalse);
    expect(BannerPlataforma.fromJson({'activo': true, 'texto': '', 'imagenUrl': null}).visible, isFalse);
  });

  test('el anuncio sale una vez al día, y otra vez si gerencia lo cambia', () async {
    SharedPreferences.setMockInitialValues({});
    final s = BannerService.instance;
    const promo = BannerPlataforma(activo: true, texto: 'Promo');
    final hoy = DateTime(2026, 9, 30, 8);

    expect(await s.tocaMostrarHoy(promo, ahora: hoy), isTrue);
    await s.marcarVisto(promo, ahora: hoy);
    expect(await s.tocaMostrarHoy(promo, ahora: hoy.add(const Duration(hours: 10))), isFalse);
    expect(await s.tocaMostrarHoy(promo, ahora: hoy.add(const Duration(days: 1))), isTrue);
    expect(await s.tocaMostrarHoy(const BannerPlataforma(activo: true, texto: 'Otra'), ahora: hoy), isTrue);
    expect(await s.tocaMostrarHoy(BannerPlataforma.vacio, ahora: hoy), isFalse);
  });

  testWidgets('la X cierra la ventana del anuncio', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => const AnuncioDialog(banner: BannerPlataforma(activo: true, texto: 'Descuento hoy')),
          ),
          child: const Text('abrir'),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Descuento hoy'), findsOneWidget);

    await tester.tap(find.byKey(const Key('cerrar_anuncio')));
    await tester.pumpAndSettle();
    expect(find.text('Descuento hoy'), findsNothing);
  });
}
