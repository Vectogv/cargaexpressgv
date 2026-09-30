import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:cargaexpress/screens/conductor/grupo_conductores_screen.dart';

import '../../helpers/fake_api.dart';

Map<String, dynamic> _grupo({required bool esLider}) => {
      'zona': 'Popayán',
      'esLider': esLider,
      'lider': {'id': 7, 'nombre': 'Luis Líder', 'telefono': '3001112233'},
      'avisos': [
        {'id': 1, 'contenido': 'Aviso normal', 'fijado': false, 'createdAt': '2026-09-30T10:00:00Z', 'autor': {'nombre': 'Luis'}},
        {'id': 2, 'contenido': 'Aviso fijado', 'fijado': true, 'createdAt': '2026-09-30T09:00:00Z', 'autor': {'nombre': 'Luis'}},
      ],
      'comunicados': [
        {'id': 3, 'titulo': 'Cierre vial', 'contenido': 'La calle 5 está cerrada', 'createdAt': '2026-09-30T08:00:00Z'},
      ],
    };

void main() {
  testWidgets('conductor normal: solo lee, sin herramientas de líder', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa((req) => jsonResp(_grupo(esLider: false)), () async {
      await tester.pumpWidget(const MaterialApp(home: GrupoConductoresScreen()));
      await avanzar(tester);
      expect(find.text('Conductores de Popayán'), findsOneWidget);
      expect(find.text('Conductor'), findsOneWidget);
      expect(find.text('Luis Líder'), findsOneWidget);
      expect(find.text('Cierre vial'), findsOneWidget);
      // El fijado va primero.
      expect(tester.getTopLeft(find.text('Aviso fijado')).dy, lessThan(tester.getTopLeft(find.text('Aviso normal')).dy));
      expect(find.byKey(const Key('grupo_btn_publicar')), findsNothing);
      expect(find.byKey(const Key('grupo_panel_lider')), findsNothing);
      expect(find.byKey(const Key('grupo_menu_aviso_1')), findsNothing);
    });
  });

  testWidgets('líder: publica un anuncio', (tester) async {
    pantallaAlta(tester);
    final log = <http.Request>[];
    await conApiFalsa(
      (req) => req.method == 'POST' ? jsonResp({'id': 9}) : jsonResp(_grupo(esLider: true)),
      () async {
        await tester.pumpWidget(const MaterialApp(home: GrupoConductoresScreen()));
        await avanzar(tester);
        expect(find.text('Líder'), findsOneWidget);
        expect(find.text('Luis Líder (tú)'), findsOneWidget);
        expect(find.byKey(const Key('grupo_panel_lider')), findsOneWidget);

        await tester.tap(find.byKey(const Key('grupo_btn_publicar')));
        await avanzar(tester);
        await tester.enterText(find.byKey(const Key('grupo_campo_contenido')), 'Reunión el viernes');
        await tester.tap(find.text('Publicar'));
        await avanzar(tester);
        expect(find.text('Anuncio publicado'), findsOneWidget);
      },
      log: log,
    );
    final post = log.firstWhere((r) => r.method == 'POST');
    expect(post.url.path, '/api/leader/avisos');
    expect(jsonDecode(post.body), {'contenido': 'Reunión el viernes'});
  });

  testWidgets('conductor: ve comentarios, comenta y borra el suyo', (tester) async {
    pantallaAlta(tester);
    final grupo = _grupo(esLider: false);
    (grupo['avisos'] as List)[0]['comentarios'] = [
      {'id': 20, 'contenido': 'Gracias', 'createdAt': '2026-09-30T10:05:00Z', 'autor': {'nombre': 'Ana', 'apellido': 'Ruiz'}, 'propio': true, 'puedeBorrar': true},
      {'id': 21, 'contenido': 'Ya pasó', 'createdAt': '2026-09-30T10:06:00Z', 'autor': {'nombre': 'Pedro', 'apellido': 'Gil'}, 'propio': false, 'puedeBorrar': false},
    ];
    final log = <http.Request>[];
    await conApiFalsa(
      (req) => req.method == 'GET' ? jsonResp(grupo) : jsonResp({'id': 22}),
      () async {
        await tester.pumpWidget(const MaterialApp(home: GrupoConductoresScreen()));
        await avanzar(tester);
        expect(find.text('Gracias'), findsOneWidget);
        expect(find.textContaining('Pedro Gil'), findsOneWidget);
        expect(find.byKey(const Key('grupo_borrar_comentario_20')), findsOneWidget);
        expect(find.byKey(const Key('grupo_borrar_comentario_21')), findsNothing);

        await tester.tap(find.byKey(const Key('grupo_comentar_1')));
        await avanzar(tester);
        await tester.enterText(find.byKey(const Key('grupo_campo_contenido')), 'Voy para allá');
        await tester.tap(find.text('Comentar').last);
        await avanzar(tester);
        expect(find.text('Comentario publicado'), findsOneWidget);

        // Cancelar no borra; confirmar sí.
        await tester.tap(find.byKey(const Key('grupo_borrar_comentario_20')));
        await avanzar(tester);
        expect(find.text('¿Borrar este comentario?'), findsOneWidget);
        await tester.tap(find.text('Cancelar'));
        await avanzar(tester);
        expect(log.where((r) => r.method == 'DELETE'), isEmpty);

        await tester.tap(find.byKey(const Key('grupo_borrar_comentario_20')));
        await avanzar(tester);
        await tester.tap(find.byKey(const Key('grupo_confirmar_borrar')));
        await avanzar(tester);
        expect(find.text('Comentario borrado'), findsOneWidget);
      },
      log: log,
    );
    final post = log.firstWhere((r) => r.method == 'POST');
    expect(post.url.path, '/api/drivers/grupo/avisos/1/comentarios');
    expect(jsonDecode(post.body), {'contenido': 'Voy para allá'});
    expect(log.firstWhere((r) => r.method == 'DELETE').url.path, '/api/drivers/grupo/comentarios/20');
  });
}
