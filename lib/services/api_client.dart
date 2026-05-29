import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static String get defaultBaseUrl {
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:3333/api';
    }
    return 'http://localhost:3333/api';
  }

  late String baseUrl;

  String? _token;
  String? get token => _token;

  static final ApiClient _instance = ApiClient._();
  ApiClient._();
  factory ApiClient() => _instance;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    baseUrl = prefs.getString('customBaseUrl') ?? defaultBaseUrl;
  }

  Future<void> setCustomBaseUrl(String url) async {
    baseUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('customBaseUrl', url);
  }

  Future<void> setToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  Future<void> setRefreshToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('refreshToken', token);
  }

  Future<void> clearTokens() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('refreshToken');
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Future<Map<String, dynamic>> get(String path, {Map<String, String>? query}) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final res = await http.get(uri, headers: _headers);
    return _handle(res);
  }

  Future<List<dynamic>> getList(String path, {Map<String, String>? query}) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final res = await http.get(uri, headers: _headers);
    return _handleList(res);
  }

  Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$baseUrl$path');
    final res = await http.post(uri, headers: _headers, body: body != null ? jsonEncode(body) : null);
    return _handle(res);
  }

  Future<Map<String, dynamic>> put(String path, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$baseUrl$path');
    final res = await http.put(uri, headers: _headers, body: body != null ? jsonEncode(body) : null);
    return _handle(res);
  }

  Future<Map<String, dynamic>> upload(String path, String filePath, String field) async {
    final uri = Uri.parse('$baseUrl$path');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll({'Authorization': 'Bearer $_token'});
    request.files.add(await http.MultipartFile.fromPath(field, filePath));
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    return _handle(res);
  }

  Future<Map<String, dynamic>> uploadBytes(String path, List<int> bytes, String filename, String field) async {
    final uri = Uri.parse('$baseUrl$path');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll({'Authorization': 'Bearer $_token'});
    request.files.add(http.MultipartFile.fromBytes(field, bytes, filename: filename));
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    return _handle(res);
  }

  Future<Map<String, dynamic>> delete(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    final res = await http.delete(uri, headers: _headers);
    return _handle(res);
  }

  Map<String, dynamic> _handle(http.Response res) {
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    throw ApiException(res.statusCode, _extractError(body));
  }

  List<dynamic> _handleList(http.Response res) {
    final body = jsonDecode(res.body) as List<dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    throw ApiException(res.statusCode, 'Error desconocido');
  }

  String _extractError(Map<String, dynamic> body) {
    if (body.containsKey('message')) return body['message'] as String;
    if (body.containsKey('error')) return body['error'] as String;
    if (body.containsKey('errors') && body['errors'] is List && (body['errors'] as List).isNotEmpty) {
      final first = (body['errors'] as List).first;
      if (first is Map && first.containsKey('message')) return first['message'] as String;
    }
    return 'Error desconocido';
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);
  @override
  String toString() => message;
}
