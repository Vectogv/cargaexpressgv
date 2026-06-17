import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_client.dart';

class HttpClient {
  static const String baseUrl = 'https://zippy-trust-production.up.railway.app';

  static Map<String, String> _headers({bool auth = false}) {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (auth && ApiClient.instance.token != null) {
      headers['Authorization'] = 'Bearer ${ApiClient.instance.token}';
    }
    return headers;
  }

  static Future<Map<String, dynamic>> get(String path, {bool auth = false}) async {
    final res = await http.get(Uri.parse('$baseUrl$path'), headers: _headers(auth: auth));
    return _handleResponse(res);
  }

  static Future<List<dynamic>> getList(String path, {bool auth = false}) async {
    final res = await http.get(Uri.parse('$baseUrl$path'), headers: _headers(auth: auth));
    if (res.statusCode != 200) throw Exception(_extractError(jsonDecode(res.body)));
    return jsonDecode(res.body) as List<dynamic>;
  }

  static Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? body, bool auth = false}) async {
    final res = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: _headers(auth: auth),
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> put(String path, {Map<String, dynamic>? body, bool auth = false}) async {
    final res = await http.put(
      Uri.parse('$baseUrl$path'),
      headers: _headers(auth: auth),
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> uploadFile(
    String path, {
    required List<int> bytes,
    required String filename,
    required String fieldName,
    bool auth = false,
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'));
    if (auth && ApiClient.instance.token != null) {
      request.headers['Authorization'] = 'Bearer ${ApiClient.instance.token}';
    }
    request.files.add(http.MultipartFile.fromBytes(fieldName, bytes, filename: filename));
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    return _handleResponse(res);
  }

  static Map<String, dynamic> _handleResponse(http.Response res) {
    final data = jsonDecode(res.body);
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception(_extractError(data));
    }
    return data as Map<String, dynamic>;
  }

  static String _extractError(dynamic data) {
    if (data is Map) {
      if (data['message'] != null) return data['message'] as String;
      final errors = data['errors'];
      if (errors is List && errors.isNotEmpty) {
        return (errors[0] as Map<String, dynamic>)['message'] as String? ?? 'Error desconocido';
      }
      if (data['error'] != null) return data['error'] as String;
    }
    return 'Error desconocido';
  }
}
