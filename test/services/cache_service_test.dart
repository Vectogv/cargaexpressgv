import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:cargaexpress/services/cache_service.dart';
import 'dart:io';

void main() {
  group('CacheService', () {
    late CacheService cache;
    late Directory tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('hive_test_');
      Hive.init(tempDir.path);
      await Hive.openBox('trips');
      await Hive.openBox('profile');
      await Hive.openBox('notifications');
      await Hive.openBox('chat');
      await Hive.openBox('preferences');
      cache = CacheService.instance;
    });

    tearDown(() async {
      await Hive.deleteBoxFromDisk('trips');
      await Hive.deleteBoxFromDisk('profile');
      await Hive.deleteBoxFromDisk('notifications');
      await Hive.deleteBoxFromDisk('chat');
      await Hive.deleteBoxFromDisk('preferences');
      tempDir.deleteSync(recursive: true);
    });

    group('profile', () {
      test('caches and retrieves profile', () {
        final profile = {'id': 'u1', 'nombre': 'Test', 'email': 't@t.com'};
        cache.cacheProfile(profile);
        final result = cache.getCachedProfile();
        expect(result, profile);
      });

      test('returns null when no profile cached', () {
        expect(cache.getCachedProfile(), isNull);
      });
    });

    group('trips', () {
      test('caches and retrieves trip history', () {
        final trips = [
          {'_id': 't1', 'estado': 'pendiente'},
          {'_id': 't2', 'estado': 'completado'},
        ];
        cache.cacheTrips(trips);
        expect(cache.getCachedTrips(), trips);
      });

      test('caches and retrieves active trip', () {
        final trip = {'_id': 't1', 'estado': 'en_curso'};
        cache.cacheActiveTrip(trip);
        expect(cache.getCachedActiveTrip(), trip);
      });

      test('clearActiveTrip removes active trip', () {
        cache.cacheActiveTrip({'_id': 't1'});
        cache.clearActiveTrip();
        expect(cache.getCachedActiveTrip(), isNull);
      });

      test('returns null when no trips cached', () {
        expect(cache.getCachedTrips(), isNull);
        expect(cache.getCachedActiveTrip(), isNull);
      });
    });

    group('notifications', () {
      test('caches and retrieves notifications', () {
        final notifications = [
          {'_id': 'n1', 'title': 'Test', 'read': false},
        ];
        cache.cacheNotifications(notifications);
        expect(cache.getCachedNotifications(), notifications);
      });
    });

    group('chat', () {
      test('caches and retrieves messages per tripId', () {
        final messages = [
          {'_id': 'm1', 'text': 'Hola'},
          {'_id': 'm2', 'text': 'Adiós'},
        ];
        cache.cacheMessages('trip1', messages);
        expect(cache.getCachedMessages('trip1'), messages);
      });

      test('different tripIds do not interfere', () {
        cache.cacheMessages('tripA', [{'_id': 'mA', 'text': 'A'}]);
        cache.cacheMessages('tripB', [{'_id': 'mB', 'text': 'B'}]);
        expect(cache.getCachedMessages('tripA')!.length, 1);
        expect(cache.getCachedMessages('tripA')!.first['text'], 'A');
        expect(cache.getCachedMessages('tripB')!.first['text'], 'B');
      });
    });

    group('preferences', () {
      test('sets and retrieves preferences', () {
        cache.setPreference('darkMode', true);
        cache.setPreference('language', 'es');
        expect(cache.getPreference('darkMode'), isTrue);
        expect(cache.getPreference('language'), 'es');
      });

      test('returns null for unset preference', () {
        expect(cache.getPreference('nonexistent'), isNull);
      });
    });

    group('clearAll', () {
      test('clears all cached data', () async {
        cache.cacheProfile({'id': 'u1'});
        cache.cacheTrips([{'_id': 't1'}]);
        cache.cacheNotifications([{'_id': 'n1'}]);
        await cache.clearAll();
        expect(cache.getCachedProfile(), isNull);
        expect(cache.getCachedTrips(), isNull);
        expect(cache.getCachedNotifications(), isNull);
      });
    });
  });
}
