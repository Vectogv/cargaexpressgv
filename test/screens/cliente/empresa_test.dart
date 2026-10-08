import 'dart:convert';

import 'package:cargaexpress/screens/cliente/empresa/mi_empresa_screen.dart';
import 'package:cargaexpress/screens/cliente/empresa/registrar_empresa_screen.dart';
import 'package:cargaexpress/screens/cliente/perfil_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../../helpers/fake_api.dart';

http.Response _perfil(http.Request req, Object? empresa, {http.Response Function(http.Request)? otras}) {
  final p = req.url.path;
  if (p == '/api/users/profile') return jsonResp({'id': 1, 'nombre': 'Ana', 'apellido': 'Gómez', 'email': 'a@a.co', 'empresa': empresa});
  if (p == '/api/payments') return jsonResp({'estadoCuenta': 'activa', 'montoDeuda': null});
  if (otras != null) return otras(req);
  return jsonResp({'data': []});
}

Future<void> _abrirPerfil(WidgetTester tester) async {
  pantallaAlta(tester);
  await tester.pumpWidget(const MaterialApp(home: PerfilScreen()));
  await avanzar(tester);
}

final _png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=');

void main() {
  group('Perfil: filas de empresa', () {
    testWidgets('sin empresa: Registrar mi empresa y Unirme a una empresa', (tester) async {
      await conApiFalsa((req) => _perfil(req, null), () async {
        await _abrirPerfil(tester);
        expect(find.text('Registrar mi empresa'), findsOneWidget);
        expect(find.text('Unirme a una empresa'), findsOneWidget);
        expect(find.text('Mi empresa'), findsNothing);
        await tester.pumpWidget(const SizedBox());
      });
    });

    for (final estado in ['pendiente', 'aprobado', 'rechazado']) {
      testWidgets('con empresa $estado: solo Mi empresa', (tester) async {
        await conApiFalsa((req) => _perfil(req, {'id': 3, 'nombre': 'Ferretería', 'estado': estado, 'esDueno': true}), () async {
          await _abrirPerfil(tester);
          expect(find.text('Mi empresa'), findsOneWidget);
          expect(find.text('Registrar mi empresa'), findsNothing);
          expect(find.text('Unirme a una empresa'), findsNothing);
          await tester.pumpWidget(const SizedBox());
        });
      });
    }

    testWidgets('unirse con un código inválido muestra el mensaje del servidor y deja el diálogo abierto', (tester) async {
      final log = <http.Request>[];
      await conApiFalsa(
        (req) => _perfil(req, null, otras: (r) {
          if (r.url.path == '/api/empresas/unirse') {
            return errorResp(422, 'Ese código no existe o la empresa no está aprobada', 'CODIGO_INVALIDO');
          }
          return jsonResp({'data': []});
        }),
        () async {
          await _abrirPerfil(tester);
          await tester.tap(find.text('Unirme a una empresa'));
          await avanzar(tester, 0.5);
          await tester.enterText(find.byType(TextField), 'zzz999');
          await tester.tap(find.text('Unirme'));
          await avanzar(tester, 0.5);
          expect(find.text('Ese código no existe o la empresa no está aprobada'), findsOneWidget);
          expect(find.text('Unirme'), findsOneWidget);
          await tester.pumpWidget(const SizedBox());
        },
        log: log,
      );
      expect(log.any((r) => r.url.path == '/api/empresas/unirse' && r.body.contains('ZZZ999')), isTrue);
    });
  });

  group('Mi empresa', () {
    Map<String, dynamic> mia({required bool dueno, String estado = 'aprobado', String? nota}) => {
          'empresa': {
            'id': 3,
            'nombre': 'Ferretería Cauca',
            'nit': '900123456',
            'direccion': 'Cra 5 #4-10',
            'telefono': '3001234567',
            'estado': estado,
            'notaRechazo': nota,
            'esDueno': dueno,
            if (dueno) 'codigo': 'FERR42',
          },
          if (dueno) 'miembros': [
            {'id': 1, 'nombre': 'Ana', 'apellido': 'Gómez', 'telefono': '3001', 'esDueno': true},
            {'id': 2, 'nombre': 'Luis', 'apellido': 'Pérez', 'telefono': '3002', 'esDueno': false},
          ],
          'resumen': dueno
              ? {
                  'mes': '2026-10',
                  'viajes': 7,
                  'total': 350000,
                  'porUsuario': [
                    {'userId': 2, 'nombre': 'Luis Pérez', 'viajes': 5, 'total': 250000}
                  ],
                  'conductores': [
                    {'conductorId': 9, 'nombre': 'Carlos', 'calificacion': 4.8, 'viajes': 4}
                  ],
                  'detalle': [],
                }
              : null,
        };

    Future<void> abrir(WidgetTester tester) async {
      pantallaAlta(tester);
      await tester.pumpWidget(const MaterialApp(home: MiEmpresaScreen()));
      await avanzar(tester);
    }

    testWidgets('dueño: código, equipo, resumen y reporte', (tester) async {
      await conApiFalsa((_) => jsonResp(mia(dueno: true)), () async {
        await abrir(tester);
        expect(find.text('Empresa verificada'), findsOneWidget);
        expect(find.text('FERR42'), findsOneWidget);
        expect(find.text('Compartir por WhatsApp'), findsOneWidget);
        expect(find.text('Luis Pérez'), findsOneWidget);
        expect(find.text('Quitar'), findsOneWidget); // el dueño no se quita
        expect(find.text('7'), findsOneWidget);
        expect(find.text('\$350.000'), findsOneWidget);
        await tester.scrollUntilVisible(find.text('Descargar reporte'), 300, scrollable: find.byType(Scrollable).first);
        expect(find.text('Descargar reporte'), findsOneWidget);
        expect(find.text('Salir de la empresa'), findsNothing);
        await tester.pumpWidget(const SizedBox());
      });
    });

    testWidgets('dueño: quitar pide confirmación y llama al servidor', (tester) async {
      final log = <http.Request>[];
      await conApiFalsa((req) {
        if (req.method == 'DELETE') return jsonResp({});
        return jsonResp(mia(dueno: true));
      }, () async {
        await abrir(tester);
        await tester.tap(find.text('Quitar'));
        await avanzar(tester, 0.5);
        expect(find.textContaining('¿Quitar a Luis Pérez?'), findsOneWidget);
        await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Quitar')));
        await avanzar(tester, 0.5);
        await tester.pumpWidget(const SizedBox());
      }, log: log);
      expect(log.any((r) => r.method == 'DELETE' && r.url.path == '/api/empresas/miembros/2'), isTrue);
    });

    testWidgets('empleado: nombre y Salir de la empresa, sin código ni equipo', (tester) async {
      await conApiFalsa((_) => jsonResp(mia(dueno: false)), () async {
        await abrir(tester);
        expect(find.text('Ferretería Cauca'), findsOneWidget);
        expect(find.text('Salir de la empresa'), findsOneWidget);
        expect(find.text('Compartir por WhatsApp'), findsNothing);
        expect(find.text('Descargar reporte'), findsNothing);
        await tester.pumpWidget(const SizedBox());
      });
    });

    testWidgets('rechazada: nota y Corregir y reenviar', (tester) async {
      await conApiFalsa((_) => jsonResp(mia(dueno: true, estado: 'rechazado', nota: 'El RUT no se lee')), () async {
        await abrir(tester);
        expect(find.text('Rechazada'), findsOneWidget);
        expect(find.textContaining('El RUT no se lee'), findsOneWidget);
        expect(find.text('Corregir y reenviar'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      });
    });

    testWidgets('en revisión: aviso y sin acciones', (tester) async {
      await conApiFalsa((_) => jsonResp(mia(dueno: true, estado: 'pendiente')), () async {
        await abrir(tester);
        expect(find.text('En revisión'), findsOneWidget);
        expect(find.text('Descargar reporte'), findsNothing);
        await tester.pumpWidget(const SizedBox());
      });
    });
  });

  group('Registrar empresa', () {
    test('NIT: solo dígitos de 6 a 15', () {
      expect(validarNit('900123456'), isNull);
      expect(validarNit('900.123.456-7'), isNotNull);
      expect(validarNit('123'), isNotNull);
      expect(validarNit(''), isNotNull);
    });

    testWidgets('un NIT repetido muestra el mensaje del servidor', (tester) async {
      pantallaAlta(tester);
      await conApiFalsa((_) => errorResp(409, 'Ya hay una empresa con ese NIT', 'NIT_REPETIDO'), () async {
        await tester.pumpWidget(MaterialApp(home: RegistrarEmpresaScreen(elegirFoto: (_) async => _png)));
        await avanzar(tester, 0.5);
        final campos = find.byType(TextFormField);
        await tester.enterText(campos.at(0), 'Ferretería Cauca');
        await tester.enterText(campos.at(1), '900123456');
        await tester.enterText(campos.at(2), 'Cra 5 #4-10');
        await tester.enterText(campos.at(3), '3001234567');
        await tester.tap(find.text('Galería').first);
        await avanzar(tester, 0.5);
        await tester.ensureVisible(find.text('Galería').last);
        await tester.pump();
        await tester.tap(find.text('Galería').last);
        await avanzar(tester, 0.5);
        final enviar = find.text('Enviar para revisión');
        await tester.ensureVisible(enviar);
        await tester.pump();
        await tester.tap(enviar);
        await avanzar(tester, 1);
        expect(find.text('Ya hay una empresa con ese NIT'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      });
    });
  });
}
