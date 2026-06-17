import 'package:dio/dio.dart';
import '../api_client.dart';

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
        final auth = await ApiClient.instance.refreshToken();
        err.requestOptions.headers['Authorization'] = 'Bearer ${auth.token}';
        final response = await Dio().fetch(err.requestOptions);
        handler.resolve(response);
        return;
      } catch (_) {
        await ApiClient.instance.logout();
      }
    }
    handler.next(err);
  }
}
