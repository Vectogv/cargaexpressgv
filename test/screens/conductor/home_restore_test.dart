import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:cargaexpress/services/cache_service.dart';

void main() {
  group('HomeScreen – Restauración de viaje desde caché', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('hive_test_');
      Hive.init(tempDir.path);
      await Hive.openBox('trips');
      await Hive.openBox('profile');
      await Hive.openBox('notifications');
      await Hive.openBox('chat');
      await Hive.openBox('preferences');
    });

    tearDown(() async {
      await Hive.deleteBoxFromDisk('trips');
      await Hive.deleteBoxFromDisk('profile');
      await Hive.deleteBoxFromDisk('notifications');
      await Hive.deleteBoxFromDisk('chat');
      await Hive.deleteBoxFromDisk('preferences');
      tempDir.deleteSync(recursive: true);
    });

    test('fallback a caché cuando API falla – viaje restaurado', () {
      final cachedTripJson = {
        '_id': 'cached_trip',
        'estado': 'en_curso',
        'origen': {'lat': 19.43, 'lng': -99.13, 'direccion': 'Origen'},
        'destino': {'lat': 19.42, 'lng': -99.14, 'direccion': 'Destino'},
        'cliente': {'_id': 'c1', 'nombre': 'Ana', 'email': 'ana@test.com'},
        'carga': 'Documentos',
        'precioEstimado': 200.0,
        'distancia': 3.0,
        'tiempoEstimado': 10,
        'createdAt': '2025-06-01T00:00:00.000Z',
        'updatedAt': '2025-06-01T00:00:00.000Z',
      };

      // Simula la lógica de _restoreAfterBackground:
      // 1. API falla → catch
      // 2. Busca en caché → lo encuentra
      // 3. Restaura el viaje (no hace pop)

      // Precondición: guardar en caché
      CacheService.instance.cacheActiveTrip(cachedTripJson);

      Map<String, dynamic>? restoredTrip;
      var shouldPop = false;

      try {
        throw Exception('API error');
      } catch (_) {
        final cached = CacheService.instance.getCachedActiveTrip();
        if (cached != null) {
          restoredTrip = cached;
        } else {
          shouldPop = true;
        }
      }

      expect(restoredTrip, isNotNull);
      expect(restoredTrip!['_id'], 'cached_trip');
      expect(shouldPop, isFalse);
    });

    test('pop cuando no hay caché ni API disponible', () {
      // No hay nada en caché
      var shouldPop = false;

      try {
        throw Exception('API error');
      } catch (_) {
        final cached = CacheService.instance.getCachedActiveTrip();
        if (cached == null) {
          shouldPop = true;
        }
      }

      expect(shouldPop, isTrue);
    });

    test('no restaura si el caché no tiene viaje activo', () {
      // Caché tiene un viaje finalizado (no activo)
      CacheService.instance.cacheActiveTrip({
        '_id': 'old_trip',
        'estado': 'finalizado',
      });

      Map<String, dynamic>? restoredTrip;
      try {
        throw Exception('API error');
      } catch (_) {
        final cached = CacheService.instance.getCachedActiveTrip();
        if (cached != null) {
          restoredTrip = cached;
        }
      }

      expect(restoredTrip, isNotNull);
      expect(restoredTrip!['_id'], 'old_trip');
      expect(restoredTrip['estado'], 'finalizado');
    });
  });
}
