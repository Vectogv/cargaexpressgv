import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:cargaexpress/services/server_clock.dart';
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
}
