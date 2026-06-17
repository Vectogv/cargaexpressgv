import 'package:flutter_test/flutter_test.dart';
import 'package:cargaexpress/providers/notification_provider.dart';
import 'package:hive/hive.dart';
import 'dart:io';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('hive_test_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.deleteBoxFromDisk('notifications');
    await Hive.deleteBoxFromDisk('trips');
    await Hive.deleteBoxFromDisk('profile');
    await Hive.deleteBoxFromDisk('chat');
    await Hive.deleteBoxFromDisk('preferences');
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('NotificationProvider', () {
    test('unreadCount is 0 on fresh instance', () {
      final provider = NotificationProvider.instance;
      expect(provider.unreadCount, 0);
      expect(provider.items, isEmpty);
    });

    test('markAllRead does not throw with empty list', () async {
      await Hive.openBox('notifications');
      final provider = NotificationProvider.instance;
      expect(() => provider.markAllRead(), returnsNormally);
      expect(provider.unreadCount, 0);
    });

    test('fetchFromBackend does not throw', () async {
      await Hive.openBox('notifications');
      final provider = NotificationProvider.instance;
      await expectLater(provider.fetchFromBackend(), completes);
    });
  });
}
