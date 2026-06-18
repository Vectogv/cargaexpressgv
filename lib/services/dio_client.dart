import 'package:dio/dio.dart';
import 'api_client.dart';
import 'interceptors/auth_interceptor.dart';
import 'logger_service.dart';
import 'network_monitor_service.dart';

class DioClient {
  static final DioClient instance = DioClient._();
  DioClient._();

  late final Dio dio;

  void init() {
    dio = Dio(BaseOptions(
      baseUrl: ApiClient.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));

    dio.interceptors.add(AuthInterceptor());
    dio.interceptors.add(RetryInterceptor());
    dio.interceptors.add(LogInterceptor(requestBody: true, responseBody: true, logPrint: (_) {}));
  }

  Future<Map<String, dynamic>> get(String path) async {
    final res = await dio.get(path);
    return res.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getList(String path) async {
    final res = await dio.get(path);
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? body}) async {
    final res = await dio.post(path, data: body);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> put(String path, {Map<String, dynamic>? body}) async {
    final res = await dio.put(path, data: body);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> uploadFile(String path, {required List<int> bytes, required String filename, required String fieldName}) async {
    final form = FormData.fromMap({
      fieldName: MultipartFile.fromBytes(bytes, filename: filename),
    });
    final res = await dio.post(path, data: form);
    return res.data as Map<String, dynamic>;
  }
}

class RetryInterceptor extends Interceptor {
  static const int _maxRetries = 3;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (_shouldRetry(err)) {
      final options = err.requestOptions;
      final extra = options.extra;
      int retryCount = extra['retry_count'] ?? 0;

      if (retryCount < _maxRetries) {
        await NetworkMonitorService.instance.waitForConnection();
        retryCount++;
        extra['retry_count'] = retryCount;
        final delay = Duration(seconds: retryCount * 2);

        LoggerService.instance.warning(
          'RetryInterceptor: retrying ${options.path} (attempt $retryCount/$_maxRetries) after ${delay.inSeconds}s',
        );

        await Future.delayed(delay);
        try {
          final response = await Dio().fetch(options);
          handler.resolve(response);
          return;
        } catch (e) {
          LoggerService.instance.error('RetryInterceptor: retry $retryCount failed for ${options.path}', e);
        }
      }
    }
    handler.next(err);
  }

  bool _shouldRetry(DioException err) {
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError) {
      return true;
    }
    if (err.response != null) {
      final code = err.response!.statusCode;
      return code == 429 || code == 503 || code == 502;
    }
    return false;
  }
}
