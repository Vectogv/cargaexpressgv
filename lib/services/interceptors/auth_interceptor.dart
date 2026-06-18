import 'package:dio/dio.dart';
import '../api_client.dart';
import '../logger_service.dart';

class AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = ApiClient.instance.token;
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      try {
        LoggerService.instance.info('AuthInterceptor: refreshing token');
        final auth = await ApiClient.instance.refreshToken();
        err.requestOptions.headers['Authorization'] = 'Bearer ${auth.token}';
        final response = await Dio().fetch(err.requestOptions);
        handler.resolve(response);
        return;
      } catch (e) {
        LoggerService.instance.error('AuthInterceptor: token refresh failed, logging out', e);
        await ApiClient.instance.logout();
      }
    }
    handler.next(err);
  }
}
