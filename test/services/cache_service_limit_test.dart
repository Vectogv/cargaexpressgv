import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:cargaexpress/services/cache_service.dart';

void main() {
  group('CacheService – Límite de 100 mensajes', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('hive_test_');
      Hive.init(tempDir.path);
      await Hive.openBox('chat');
    });

    tearDown(() async {
      await Hive.deleteBoxFromDisk('chat');
      tempDir.deleteSync(recursive: true);
    });

    test('cacheMessages recorta a 100 cuando hay más de 100 mensajes', () {
      final messages = List<Map<String, dynamic>>.generate(
        150,
        (i) => {'_id': 'msg$i', 'text': 'Mensaje $i'},
      );

      CacheService.instance.cacheMessages('trip_001', messages);
      final retrieved = CacheService.instance.getCachedMessages('trip_001');

      expect(retrieved, isNotNull);
      expect(retrieved!.length, 100);
    });

    test('los mensajes guardados son los últimos 100', () {
      final messages = List<Map<String, dynamic>>.generate(
        150,
        (i) => {'_id': 'msg$i', 'text': 'Mensaje $i'},
      );

      CacheService.instance.cacheMessages('trip_001', messages);
      final retrieved = CacheService.instance.getCachedMessages('trip_001')!;

      // El primer mensaje guardado debe ser msg50 (el 51° original)
      expect(retrieved.first['_id'], 'msg50');
      expect(retrieved.first['text'], 'Mensaje 50');

      // El último mensaje debe ser msg149
      expect(retrieved.last['_id'], 'msg149');
      expect(retrieved.last['text'], 'Mensaje 149');
    });

    test('no recorta cuando hay exactamente 100 mensajes', () {
      final messages = List<Map<String, dynamic>>.generate(
        100,
        (i) => {'_id': 'msg$i', 'text': 'Mensaje $i'},
      );

      CacheService.instance.cacheMessages('trip_001', messages);
      final retrieved = CacheService.instance.getCachedMessages('trip_001')!;

      expect(retrieved.length, 100);
      expect(retrieved.first['_id'], 'msg0');
      expect(retrieved.last['_id'], 'msg99');
    });

    test('no recorta cuando hay menos de 100 mensajes', () {
      final messages = List<Map<String, dynamic>>.generate(
        30,
        (i) => {'_id': 'msg$i', 'text': 'Mensaje $i'},
      );

      CacheService.instance.cacheMessages('trip_001', messages);
      final retrieved = CacheService.instance.getCachedMessages('trip_001')!;

      expect(retrieved.length, 30);
    });

    test('tripIds diferentes no interfieren con el límite', () {
      final msgsA = List<Map<String, dynamic>>.generate(
        150,
        (i) => {'_id': 'a$i', 'text': 'A $i'},
      );
      final msgsB = List<Map<String, dynamic>>.generate(
        50,
        (i) => {'_id': 'b$i', 'text': 'B $i'},
      );

      CacheService.instance.cacheMessages('trip_A', msgsA);
      CacheService.instance.cacheMessages('trip_B', msgsB);

      expect(CacheService.instance.getCachedMessages('trip_A')!.length, 100);
      expect(CacheService.instance.getCachedMessages('trip_B')!.length, 50);
    });
  });
}
