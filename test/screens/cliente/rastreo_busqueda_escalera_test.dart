import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:cargaexpress/screens/cliente/rastreo_screen.dart';

import '../../helpers/fake_api.dart';

/// Escalera de acompañamiento en el rastreo: el objeto `busqueda` llega en el
/// payload de siempre (`/trips/active`) y las tarjetas de la vista llaman a
/// `PUT /trips/:id/precio` y `POST /trips/:id/seguir-esperando`.
Map<String, dynamic> _viaje(Map<String, dynamic> busqueda) => {
      '_id': 't1',
      'estado': 'buscando_conductor',
      'precioEstimado': 150000,
      'origen': {'lat': 4.6, 'lng': -74.1, 'direccion': 'Calle 1'},
      'destino': {'lat': 4.7, 'lng': -74.0, 'direccion': 'Calle 2'},
      'busqueda': busqueda,
    };

Future<List<http.Request>> _abrir(WidgetTester tester, Map<String, dynamic> busqueda, String boton) async {
  pantallaAlta(tester);
  final log = <http.Request>[];
  await conApiFalsa((req) {
    final p = req.url.path;
    if (p == '/api/trips/active') return jsonResp(_viaje(busqueda));
    if (p.endsWith('/nearby-drivers')) return jsonResp({'conductores': []});
    if (p == '/api/trips/t1/offers') return jsonResp([]);
    return jsonResp({'ok': true});
  }, () async {
    await tester.pumpWidget(const MaterialApp(home: RastreoScreen()));
    await avanzar(tester);
    await tester.pump();

    await tester.ensureVisible(find.byKey(Key(boton)));
    await tester.pump();
    await tester.tap(find.byKey(Key(boton)));
    await avanzar(tester);
  }, log: log);
  return log;
}

void main() {
  testWidgets('"Subir a \$X" llama a PUT /trips/:id/precio con el mínimo sugerido', (tester) async {
    final log = await _abrir(tester, {
      'etapa': 'sugerencia',
      'mensaje': 'Los conductores están pidiendo un poco más',
      'precioSugerido': {'min': 170000, 'max': 190000},
      'cierreHasta': null,
    }, 'btn_subir_precio');

    final put = log.where((r) => r.method == 'PUT' && r.url.path == '/api/trips/t1/precio').toList();
    expect(put, hasLength(1));
    expect(jsonDecode(put.single.body), {'precio': 170000});
  });

  testWidgets('"Seguir esperando" llama a POST /trips/:id/seguir-esperando', (tester) async {
    final log = await _abrir(tester, {
      'etapa': 'cierre',
      'mensaje': 'Todavía no hay conductor',
      'precioSugerido': null,
      'cierreHasta': '2026-10-07T20:00:00.000Z',
    }, 'btn_seguir_esperando');

    expect(log.where((r) => r.method == 'POST' && r.url.path == '/api/trips/t1/seguir-esperando'), hasLength(1));
  });
}
