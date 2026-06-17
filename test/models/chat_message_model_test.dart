import 'package:flutter_test/flutter_test.dart';
import 'package:cargaexpress/models/chat_message_model.dart';

void main() {
  group('ChatMessageModel', () {
    final completeJson = {
      '_id': 'msg123',
      'tripId': 'trip456',
      'senderId': 'user789',
      'text': 'Hola, ¿dónde estás?',
      'timestamp': '2025-01-01T12:00:00Z',
      'isSent': true,
      'status': 'sent',
    };

    group('fromJson', () {
      test('creates model from complete JSON', () {
        final model = ChatMessageModel.fromJson(completeJson);
        expect(model.id, 'msg123');
        expect(model.tripId, 'trip456');
        expect(model.senderId, 'user789');
        expect(model.text, 'Hola, ¿dónde estás?');
        expect(model.isSent, isTrue);
        expect(model.status, 'sent');
      });

      test('handles viaje key for tripId', () {
        final json = {'_id': 'm1', 'viaje': 't1'};
        expect(ChatMessageModel.fromJson(json).tripId, 't1');
      });

      test('handles null fields', () {
        final json = {'_id': 'm1'};
        final model = ChatMessageModel.fromJson(json);
        expect(model.text, isNull);
        expect(model.isSent, isNull);
        expect(model.status, isNull);
      });
    });

    group('toJson', () {
      test('serializes correctly', () {
        final model = ChatMessageModel.fromJson(completeJson);
        final json = model.toJson();
        expect(json['text'], 'Hola, ¿dónde estás?');
        expect(json['isSent'], isTrue);
      });

      test('omits null fields', () {
        final model = ChatMessageModel(id: 'm1');
        final json = model.toJson();
        expect(json.keys, ['_id']);
      });
    });

    group('copyWith', () {
      test('overrides specified fields', () {
        final a = ChatMessageModel(id: '1', text: 'Old');
        final b = a.copyWith(text: 'New');
        expect(b.text, 'New');
        expect(b.id, '1');
      });
    });
  });
}
