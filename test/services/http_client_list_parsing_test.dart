import 'package:flutter_test/flutter_test.dart';

import 'package:cargaexpress/services/api/http_client.dart';

void main() {
  group('HttpClient.parseListResponse', () {
    test('accepts a plain list (contrato api_spec)', () {
      final result = HttpClient.parseListResponse(
        <dynamic>[{'id': 1}, {'id': 2}],
        '/api/trips/nearby',
      );
      expect(result, hasLength(2));
    });

    test('accepts {data: [...]} (contrato mock/backend)', () {
      final result = HttpClient.parseListResponse(
        <String, dynamic>{'data': <dynamic>[{'id': 1}]},
        '/api/trips/nearby',
      );
      expect(result, hasLength(1));
    });

    test('throws on invalid shape instead of crashing with TypeError', () {
      expect(
        () => HttpClient.parseListResponse(
          <String, dynamic>{'message': 'ok'},
          '/api/notifications',
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('HttpClient.parseListLenient', () {
    test('accepts a plain list', () {
      expect(
        HttpClient.parseListLenient(<dynamic>[{'id': 1}]),
        hasLength(1),
      );
    });

    test('accepts {data: [...]} (formato paginado de admin)', () {
      expect(
        HttpClient.parseListLenient(<String, dynamic>{
          'data': <dynamic>[{'id': 1}],
          'total': 1,
          'page': 1,
          'limit': 20,
        }),
        hasLength(1),
      );
    });

    test('returns empty list on unknown shape (no lanza)', () {
      expect(
        HttpClient.parseListLenient(<String, dynamic>{'message': 'ok'}),
        isEmpty,
      );
      expect(HttpClient.parseListLenient(null), isEmpty);
      expect(HttpClient.parseListLenient('cadena'), isEmpty);
    });
  });
}