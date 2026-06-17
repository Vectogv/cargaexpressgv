import 'package:flutter_test/flutter_test.dart';
import 'package:cargaexpress/models/notification_item_model.dart';

void main() {
  group('NotificationItemModel', () {
    final completeJson = {
      '_id': 'notif123',
      'title': 'Nuevo viaje',
      'body': 'Tienes un viaje disponible',
      'type': 'new_trip',
      'read': false,
      'data': {'tripId': 'trip456'},
      'createdAt': '2025-01-01T00:00:00Z',
    };

    group('fromJson', () {
      test('creates model from complete JSON', () {
        final model = NotificationItemModel.fromJson(completeJson);
        expect(model.id, 'notif123');
        expect(model.title, 'Nuevo viaje');
        expect(model.body, 'Tienes un viaje disponible');
        expect(model.type, 'new_trip');
        expect(model.read, isFalse);
        expect(model.data, {'tripId': 'trip456'});
      });

      test('handles null data', () {
        final json = {'_id': 'n1', 'title': 'Test', 'data': null};
        final model = NotificationItemModel.fromJson(json);
        expect(model.data, isNull);
      });

      test('handles null read', () {
        final json = {'_id': 'n1'};
        expect(NotificationItemModel.fromJson(json).read, isNull);
      });
    });

    group('toJson', () {
      test('serializes correctly', () {
        final model = NotificationItemModel.fromJson(completeJson);
        final json = model.toJson();
        expect(json['title'], 'Nuevo viaje');
        expect(json['data'], {'tripId': 'trip456'});
      });
    });

    group('copyWith', () {
      test('overrides read state', () {
        final a = NotificationItemModel(id: '1', read: false);
        final b = a.copyWith(read: true);
        expect(b.read, isTrue);
      });
    });
  });
}
