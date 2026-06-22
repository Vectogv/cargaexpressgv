import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cargaexpress/services/session_monitor_service.dart';
import 'package:cargaexpress/services/api_client.dart';
import 'package:cargaexpress/services/cache_service.dart';
import 'package:cargaexpress/services/auth_response.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockCacheService extends Mock implements CacheService {}

void main() {
  group('SessionMonitorService', () {
    late SessionMonitorService service;

    setUp(() {
      service = SessionMonitorService.instance;
    });

    tearDown(() async {
      service.stop();
    });

    group('start / stop', () {
      test('start does not throw', () {
        expect(() => service.start(), returnsNormally);
      });

      test('start is idempotent', () {
        service.start();
        expect(() => service.start(), returnsNormally);
      });

      test('stop does not throw when not started', () {
        expect(() => service.stop(), returnsNormally);
      });

      test('stop is idempotent', () {
        service.stop();
        expect(() => service.stop(), returnsNormally);
      });

      test('start then stop', () {
        service.start();
        expect(() => service.stop(), returnsNormally);
      });
    });

    group('checkHealth', () {
      late MockApiClient mockApiClient;
      late MockCacheService mockCacheService;
      final authResponse = AuthResponse(
        token: 'test-token',
        refreshToken: 'test-refresh',
        id: 'test-id',
        nombre: 'Test',
        apellido: 'User',
        email: 'test@test.com',
        rol: 'cliente',
      );

      setUp(() {
        mockApiClient = MockApiClient();
        mockCacheService = MockCacheService();
      });

      test('stops service when token is null', () async {
        when(() => mockApiClient.token).thenReturn(null);

        await service.checkHealth(client: mockApiClient);

        verifyNever(() => mockApiClient.getProfile());
        expect(() => service.stop(), returnsNormally);
      });

      test('logs ok when profile fetch succeeds', () async {
        when(() => mockApiClient.token).thenReturn('valid-token');
        when(() => mockApiClient.getProfile())
            .thenAnswer((_) async => <String, dynamic>{'id': 'u1'});

        await service.checkHealth(client: mockApiClient);

        verify(() => mockApiClient.getProfile()).called(1);
      });

      test('recovers from cache when profile fetch fails', () async {
        when(() => mockApiClient.token).thenReturn('valid-token');
        when(() => mockApiClient.getProfile())
            .thenThrow(Exception('Network error'));
        when(() => mockCacheService.getCachedProfile())
            .thenReturn({'id': 'cached-u1'});
        when(() => mockApiClient.refreshToken())
            .thenAnswer((_) async => authResponse);

        await service.checkHealth(
            client: mockApiClient, cache: mockCacheService);

        verify(() => mockApiClient.getProfile()).called(1);
        verify(() => mockCacheService.getCachedProfile()).called(1);
        verify(() => mockApiClient.refreshToken()).called(1);
      });

      test('attempts token refresh when profile and cache fail', () async {
        when(() => mockApiClient.token).thenReturn('valid-token');
        when(() => mockApiClient.getProfile())
            .thenThrow(Exception('Network error'));
        when(() => mockCacheService.getCachedProfile()).thenReturn(null);
        when(() => mockApiClient.refreshToken())
            .thenAnswer((_) async => authResponse);

        await service.checkHealth(
            client: mockApiClient, cache: mockCacheService);

        verify(() => mockApiClient.refreshToken()).called(1);
      });

      test('handles full recovery failure gracefully', () async {
        when(() => mockApiClient.token).thenReturn('valid-token');
        when(() => mockApiClient.getProfile())
            .thenThrow(Exception('Network error'));
        when(() => mockCacheService.getCachedProfile()).thenReturn(null);
        when(() => mockApiClient.refreshToken())
            .thenThrow(Exception('Refresh failed'));

        await service.checkHealth(
            client: mockApiClient, cache: mockCacheService);

        verify(() => mockApiClient.getProfile()).called(1);
        verify(() => mockApiClient.refreshToken()).called(1);
      });
    });
  });
}
