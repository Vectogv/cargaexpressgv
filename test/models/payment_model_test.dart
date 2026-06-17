import 'package:flutter_test/flutter_test.dart';
import 'package:cargaexpress/models/payment_model.dart';

void main() {
  group('PaymentModel', () {
    final completeJson = {
      'id': 'pay123',
      'tripId': 'trip456',
      'amount': 150.50,
      'method': 'tarjeta',
      'status': 'paid',
      'reference': 'REF-001',
      'createdAt': '2025-01-01T00:00:00Z',
    };

    group('fromJson', () {
      test('creates model from complete JSON', () {
        final model = PaymentModel.fromJson(completeJson);
        expect(model.id, 'pay123');
        expect(model.tripId, 'trip456');
        expect(model.amount, 150.50);
        expect(model.method, 'tarjeta');
        expect(model.status, 'paid');
        expect(model.reference, 'REF-001');
      });

      test('handles tripId as number', () {
        final json = {'id': 'p1', 'tripId': 12345};
        expect(PaymentModel.fromJson(json).tripId, '12345');
      });

      test('parses amount from string', () {
        final json = {'id': 'p1', 'amount': '250.75'};
        expect(PaymentModel.fromJson(json).amount, 250.75);
      });

      test('handles null amount', () {
        final json = {'id': 'p1', 'amount': null};
        expect(PaymentModel.fromJson(json).amount, isNull);
      });
    });

    group('toJson', () {
      test('serializes correctly', () {
        final model = PaymentModel.fromJson(completeJson);
        final json = model.toJson();
        expect(json['amount'], 150.50);
        expect(json['status'], 'paid');
      });

      test('omits null id', () {
        final model = PaymentModel(amount: 100);
        final json = model.toJson();
        expect(json.containsKey('id'), isFalse);
      });
    });

    group('copyWith', () {
      test('overrides specified fields', () {
        final a = PaymentModel(id: '1', status: 'pending');
        final b = a.copyWith(status: 'paid');
        expect(b.status, 'paid');
        expect(b.id, '1');
      });
    });
  });
}
