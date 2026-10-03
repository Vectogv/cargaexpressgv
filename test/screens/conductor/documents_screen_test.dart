import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:cargaexpress/screens/conductor/documents_screen.dart';

import '../../helpers/fake_api.dart';

void main() {
  Map<String, dynamic> conductor = {};

  http.Response backend(http.Request req) {
    final p = req.url.path;
    if (p == '/api/users/profile') return jsonResp({'id': 1, 'nombre': 'Luis', 'conductor': conductor});
    if (p == '/api/drivers/verification-soat/excepcion' && req.method == 'POST') {
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      conductor['excepcionSoatEstado'] = 'pendiente';
      conductor['excepcionSoatNota'] = body['comentario'];
      return jsonResp({'excepcionSoatEstado': 'pendiente'});
    }
    return jsonResp({});
  }

  const enlace = '¿No tienes SOAT?';
  const revisando = 'El equipo de Carga Express está revisando tu solicitud.';

  testWidgets('muestra las tarjetas nuevas y la solicitud de validación del SOAT la deja en validación', skip: !soatActivo, (tester) async {
    pantallaAlta(tester);
    conductor = {'estadoVerificacion': 'pendiente', 'fotoSoat': null, 'fotoLicencia': '/storage/lic.png', 'excepcionSoatEstado': null};
    final log = <http.Request>[];
    await conApiFalsa(backend, () async {
      await tester.pumpWidget(const MaterialApp(home: DocumentsScreen()));
      await avanzar(tester, 1);

      for (final titulo in ['Cédula (frente)', 'Cédula (reverso)', 'Tarjeta de propiedad', 'Revisión técnico-mecánica', 'SOAT']) {
        expect(find.text(titulo), findsOneWidget, reason: titulo);
      }
      // Sin foto: chip "Pendiente" + Subir; con foto y verificación global pendiente: "En validación".
      expect(find.text('Pendiente'), findsWidgets);
      expect(find.text('En validación'), findsOneWidget);
      expect(find.text('En revisión'), findsNothing);
      expect(find.text(enlace), findsOneWidget);

      await tester.tap(find.byKey(const Key('soat_excepcion')));
      await avanzar(tester, 1);
      expect(find.text('Solicitud de validación'), findsOneWidget);
      // Asunto y tipo fijos, no editables.
      expect(tester.widget<TextFormField>(find.widgetWithText(TextFormField, 'SOAT')).enabled, isFalse);
      expect(tester.widget<TextFormField>(find.widgetWithText(TextFormField, 'Validación de vehículo')).enabled, isFalse);
      await tester.enterText(find.byKey(const Key('campo_info_soat')), 'Moto de carga sin SOAT');
      await tester.tap(find.byKey(const Key('btn_enviar_soat')));
      await avanzar(tester, 1);

      final post = log.firstWhere((r) => r.url.path == '/api/drivers/verification-soat/excepcion');
      expect(jsonDecode(post.body)['comentario'], 'Moto de carga sin SOAT');
      expect(find.text('Solicitud enviada'), findsWidgets);
      expect(find.text('Tu solicitud fue recibida correctamente.'), findsOneWidget);
      expect(find.text(revisando), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn_volver_documentos')));
      await avanzar(tester, 1);
      expect(find.text(revisando), findsOneWidget);
      expect(find.text(enlace), findsNothing);
    }, log: log);
  });

  test('estadoDocumento: una sola derivación para el panel del inicio y Documentación', () {
    expect(estadoDocumento(null, 'soat'), 'pendiente');
    expect(estadoDocumento({'estadoVerificacion': 'pendiente'}, 'licencia'), 'pendiente');
    expect(estadoDocumento({'estadoVerificacion': 'pendiente', 'fotoLicencia': 'x'}, 'licencia'), 'en_validacion');
    expect(estadoDocumento({'estadoVerificacion': 'aprobado', 'fotoLicencia': 'x'}, 'licencia'), 'aprobado');
    expect(estadoDocumento({'estadoVerificacion': 'rechazado', 'fotoSoat': 'x'}, 'soat'), 'rechazado');
    // Excepción del SOAT: sin foto, el estado lo da la solicitud.
    expect(estadoDocumento({'estadoVerificacion': 'pendiente', 'excepcionSoatEstado': 'pendiente'}, 'soat'), 'en_validacion');
    expect(estadoDocumento({'estadoVerificacion': 'pendiente', 'excepcionSoatEstado': 'aprobada'}, 'soat'), 'aprobado');
    expect(estadoDocumento({'estadoVerificacion': 'pendiente', 'excepcionSoatEstado': 'rechazada'}, 'soat'), 'pendiente');
  });

  testWidgets('SOAT vencido se marca en rojo y sin enlace de excepción', skip: !soatActivo, (tester) async {
    pantallaAlta(tester);
    conductor = {
      'estadoVerificacion': 'pendiente',
      'fotoSoat': '/storage/uploads/soat-1.png',
      'soatVence': '2020-01-15',
      'fotoTecnomecanica': '/storage/uploads/tm-1.png',
      'tecnomecanicaVence': '2099-12-31',
      'excepcionSoatEstado': 'rechazada',
      'excepcionSoatNota': 'Trae el SOAT',
    };
    await conApiFalsa(backend, () async {
      await tester.pumpWidget(const MaterialApp(home: DocumentsScreen()));
      await avanzar(tester, 1);

      final vencido = tester.widget<Text>(find.text('Vencido el 15/01/2020'));
      expect(vencido.style?.color, const Color(0xFFDC2626));
      expect(find.text('Vence el 31/12/2099'), findsOneWidget);
      // Con SOAT subido no se ofrece la excepción aunque esté vencido.
      expect(find.text(enlace), findsNothing);
    });
  });

  testWidgets('excepción del SOAT aprobada se muestra sin enlace', skip: !soatActivo, (tester) async {
    pantallaAlta(tester);
    conductor = {'estadoVerificacion': 'pendiente', 'fotoSoat': null, 'excepcionSoatEstado': 'aprobada'};
    await conApiFalsa(backend, () async {
      await tester.pumpWidget(const MaterialApp(home: DocumentsScreen()));
      await avanzar(tester, 1);
      expect(find.text('Excepción del SOAT aprobada'), findsOneWidget);
      expect(find.text(enlace), findsNothing);
    });
  });
}
