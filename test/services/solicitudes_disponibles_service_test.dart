import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

import 'package:cargaexpress/services/cache_service.dart';

import 'package:cargaexpress/services/server_clock.dart';
import 'package:cargaexpress/services/socket_service_client.dart';
import 'package:cargaexpress/services/solicitudes_disponibles_service.dart';

import '../helpers/fake_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DateTime ahora;
  late List<Map<String, dynamic>> cercanos;
  late List<Map<String, dynamic>> ofertas;
  late List<String> rutas;

  http.Response backend(http.Request req) {
    rutas.add('${req.url.path}?${req.url.query}');
    if (req.url.path == '/api/trips/nearby') return jsonResp(cercanos);
    if (req.url.path == '/api/drivers/offers') return jsonResp(ofertas);
    return jsonResp({});
  }

  Map<String, dynamic> viaje(String id) => {
        'id': id,
        '_id': id,
        'estado': 'buscando_conductor',
        'precioEstimado': 50000,
        'createdAt': ahora.toIso8601String(),
        'origen': {'direccion': 'Origen $id', 'lat': 4.6, 'lng': -74.0},
        'destino': {'direccion': 'Destino $id', 'lat': 4.7, 'lng': -74.1},
      };

  setUp(() {
    ahora = DateTime.utc(2026, 9, 25, 14);
    ServerClock.ahoraLocal = () => ahora;
    cercanos = [];
    ofertas = [];
    rutas = [];
    SolicitudesDisponiblesService.instance.reiniciarParaTest();
  });

  tearDown(() {
    SolicitudesDisponiblesService.instance.reiniciarParaTest();
    ServerClock.reiniciar();
  });

  test('sin GPS consulta /nearby sin lat/lng (el backend usa la última ubicación guardada) y cruza con mis ofertas', () async {
    cercanos = [viaje('5'), viaje('6')];
    ofertas = [
      {'id': '31', 'viajeId': '6', 'monto': 55000, 'expiresAt': ahora.add(const Duration(seconds: 20)).toIso8601String()},
      {'id': '30', 'viajeId': '5', 'monto': 40000, 'expiresAt': ahora.subtract(const Duration(seconds: 5)).toIso8601String()},
    ];
    await conApiFalsa(backend, () async {
      final s = SolicitudesDisponiblesService.instance;
      s.iniciar();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(rutas, contains('/api/trips/nearby?radio=20.0'));
      final lista = s.solicitudes;
      expect(lista.map((x) => x.id), containsAll(['5', '6']));
      final seis = lista.firstWhere((x) => x.id == '6');
      expect(seis.tieneOferta, isTrue);
      expect(seis.oferta!.monto, 55000);
      // La oferta vencida no cuenta como pendiente.
      expect(lista.firstWhere((x) => x.id == '5').tieneOferta, isFalse);
    });
  });

  test('el aviso de socket se conserva hasta que el sondeo lo confirme o pasen 30 s; quitar y registrarOferta', () async {
    await conApiFalsa(backend, () async {
      final s = SolicitudesDisponiblesService.instance;
      s.iniciar();
      await Future<void>.delayed(Duration.zero);

      s.ingresarAvisoSocket({'tripId': '9', 'origen': 'Calle 1', 'precioEstimado': 30000});
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(s.solicitudes.map((x) => x.id), ['9']);
      expect(s.solicitudes.first.viaje['origen'], {'direccion': 'Calle 1'});

      // El sondeo todavía no lo trae: se conserva (aviso reciente).
      await s.sincronizar();
      expect(s.solicitudes.map((x) => x.id), ['9']);

      // Ya lo trae: se reemplaza por los datos completos.
      cercanos = [viaje('9')];
      await s.sincronizar();
      expect(s.solicitudes.first.viaje['destino'], isNotNull);

      s.registrarOferta('9', monto: 32000, venceEn: ahora.add(const Duration(seconds: 28)));
      expect(s.solicitudes.first.tieneOferta, isTrue);
      expect(s.solicitudes.first.oferta!.monto, 32000);

      s.quitar('9');
      expect(s.solicitudes, isEmpty);

      s.detener();
      expect(s.activo, isFalse);
      // Detenido no ingresa avisos.
      s.ingresarAvisoSocket({'tripId': '10', 'origen': 'x'});
      expect(s.solicitudes, isEmpty);
    });
  });

  group('rechazos que sobreviven a un reinicio de la app', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('hive_rechazos_');
      Hive.init(tempDir.path);
      await Hive.openBox('preferences');
    });

    tearDown(() async {
      await Hive.deleteBoxFromDisk('preferences');
      tempDir.deleteSync(recursive: true);
    });

    Future<void> tick() async {
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
    }

    test('offer:rejected se guarda en el teléfono y al reiniciar la tarjeta sigue diciendo que el cliente rechazó la oferta', () async {
      cercanos = [viaje('5')];
      ofertas = [
        {'id': '31', 'viajeId': '5', 'monto': 55000, 'expiresAt': ahora.add(const Duration(seconds: 20)).toIso8601String()},
      ];
      await conApiFalsa(backend, () async {
        final s = SolicitudesDisponiblesService.instance;
        s.iniciar();
        await tick();
        expect(s.solicitudes.single.tieneOferta, isTrue);

        // El cliente la rechaza (el backend deja de devolverla como pendiente).
        ofertas = [];
        SocketServiceClient.instance.simularEventoParaTest('offer:rejected', {'viajeId': '5', 'ofertaId': '31'});
        await tick();
        expect(s.solicitudes.single.ofertaRechazada, isTrue);
        expect(CacheService.instance.getPreference(SolicitudesDisponiblesService.preferenciaRechazadas), contains('"5"'));

        // "Reinicio": el servicio arranca de cero (como al abrir la app).
        s.detener();
        expect(s.solicitudes, isEmpty);
        s.iniciar();
        await tick();
        expect(s.solicitudes.single.id, '5');
        expect(s.solicitudes.single.ofertaRechazada, isTrue);
        expect(s.solicitudes.single.tieneOferta, isFalse);

        // Al ofertar de nuevo, o cuando el viaje desaparece, se olvida.
        s.registrarOferta('5', monto: 60000, venceEn: ahora.add(const Duration(seconds: 28)));
        expect(s.solicitudes.single.ofertaRechazada, isFalse);
        expect(CacheService.instance.getPreference(SolicitudesDisponiblesService.preferenciaRechazadas), isNot(contains('"5"')));
      });
    });

    test('un rechazo más viejo que la búsqueda del backend ya no se recuerda', () async {
      cercanos = [viaje('5')];
      final viejo = ahora.subtract(SolicitudesDisponiblesService.vigenciaRechazo + const Duration(minutes: 1));
      CacheService.instance.setPreference(
        SolicitudesDisponiblesService.preferenciaRechazadas,
        '{"5": "${viejo.toIso8601String()}", "6": "${ahora.subtract(const Duration(minutes: 1)).toIso8601String()}"}',
      );
      cercanos = [viaje('5'), viaje('6')];
      await conApiFalsa(backend, () async {
        final s = SolicitudesDisponiblesService.instance;
        s.iniciar();
        await tick();
        expect(s.solicitudes.firstWhere((x) => x.id == '5').ofertaRechazada, isFalse);
        expect(s.solicitudes.firstWhere((x) => x.id == '6').ofertaRechazada, isTrue);
      });
    });
  });
}
