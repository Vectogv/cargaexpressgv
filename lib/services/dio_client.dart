import 'package:dio/dio.dart';
import 'api_client.dart';
import 'interceptors/auth_interceptor.dart';

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
