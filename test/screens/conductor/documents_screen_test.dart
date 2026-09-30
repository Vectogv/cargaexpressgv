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

  const enlace = '¿No tienes SOAT? Contacta al equipo CargaExpress para valorar el vehículo';

  testWidgets('muestra las tarjetas nuevas y pedir la excepción del SOAT la deja en revisión', (tester) async {
    pantallaAlta(tester);
    conductor = {'estadoVerificacion': 'pendiente', 'fotoSoat': null, 'excepcionSoatEstado': null};
    final log = <http.Request>[];
    await conApiFalsa(backend, () async {
      await tester.pumpWidget(const MaterialApp(home: DocumentsScreen()));
      await avanzar(tester, 1);

      for (final titulo in ['Cédula (frente)', 'Cédula (reverso)', 'Tarjeta de propiedad', 'Revisión técnico-mecánica', 'SOAT']) {
        expect(find.text(titulo), findsOneWidget, reason: titulo);
      }
      expect(find.text(enlace), findsOneWidget);

      await tester.tap(find.byKey(const Key('soat_excepcion')));
      await avanzar(tester, 1);
      await tester.enterText(find.byType(TextField), 'Moto de carga sin SOAT');
      await tester.tap(find.text('Enviar solicitud'));
      await avanzar(tester, 1);

      final post = log.firstWhere((r) => r.url.path == '/api/drivers/verification-soat/excepcion');
      expect(jsonDecode(post.body)['comentario'], 'Moto de carga sin SOAT');
      expect(find.text('Excepción del SOAT en revisión'), findsOneWidget);
      expect(find.text(enlace), findsNothing);
      expect(find.text('Solicitud enviada. Te avisaremos cuando la revisen.'), findsOneWidget);
    }, log: log);
  });

  testWidgets('SOAT vencido se marca en rojo y sin enlace de excepción', (tester) async {
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

  testWidgets('excepción del SOAT aprobada se muestra sin enlace', (tester) async {
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
