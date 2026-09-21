import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;
import '../../core/environment.dart';
import '../api_client.dart';
import '../error_handler_service.dart';
import '../logger_service.dart';
import '../network_monitor_service.dart';
import '../performance_monitor.dart';

class HttpClient {
  static String get baseUrl => Environment.baseUrl;

  /// Timeout aplicado a todas las peticiones para evitar esperas infinitas.
  static const Duration _timeout = Duration(seconds: 20);

  /// Evita refresh en cascada cuando varias peticiones reciben 401 a la vez:
  /// todas comparten el mismo Future de renovación de sesión.
  static Future<bool>? _refreshing;

  /// Ejecuta la petición; ante 401 con auth intenta renovar el token y
  /// reintenta una vez. Si el refresh falla, emite sesión expirada.
  static Future<http.Response> _execute(
    Future<http.Response> Function() request,
    String path, {
    required bool auth,
  }) async {
    var res = await _send(request);
    if (res.statusCode == 401 && auth) {
      _refreshing ??= _refreshSession();
      try {
        final ok = await _refreshing;
        if (ok == true) {
          LoggerService.instance.info('HttpClient: token refrescado, reintentando $path');
          res = await _send(request);
        } else {
          LoggerService.instance.error('HttpClient: refresh fall\u00f3, sesi\u00f3n expirada');
          ErrorHandlerService.instance.emitSessionExpired();
          throw Exception('Sesi\u00f3n expirada. Inicia sesi\u00f3n nuevamente.');
        }
      } finally {
        _refreshing = null;
      }
    }
    return res;
  }

  /// Traduce fallos de red a un ApiException con mensaje legible para el usuario
  /// (en vez de mostrar "TimeoutException after..." o "ClientException: ...").
  static Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request().timeout(_timeout);
    } on TimeoutException {
      throw ApiException('El servidor tardó demasiado en responder. Intenta de nuevo.', code: 'TIMEOUT');
    } on http.ClientException {
      throw ApiException('Sin conexión a internet. Revisa tu red e intenta de nuevo.', code: 'SIN_CONEXION');
    }
  }

  static Future<bool> _refreshSession() async {
    try {
      await ApiClient.instance.refreshToken();
      return true;
    } catch (_) {
      return false;
    }
  }

  static Map<String, String> _headers({bool auth = false}) {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (auth && ApiClient.instance.token != null) {
      headers['Authorization'] = 'Bearer ${ApiClient.instance.token}';
    }
    return headers;
  }

  static Future<Map<String, dynamic>> get(String path, {bool auth = false}) async {
    final start = DateTime.now().millisecondsSinceEpoch;
    await _waitForNetwork();
    final res = await _execute(
      () => http.get(Uri.parse('$baseUrl$path'), headers: _headers(auth: auth)),
      path,
      auth: auth,
    );
    final duration = DateTime.now().millisecondsSinceEpoch - start;
    PerformanceMonitor.instance.recordApiCall('GET $path', duration, isError: res.statusCode >= 400);
    return _handleResponse(res);
  }

  static Future<List<dynamic>> getList(String path, {bool auth = false}) async {
    final start = DateTime.now().millisecondsSinceEpoch;
    await _waitForNetwork();
    final res = await _execute(
      () => http.get(Uri.parse('$baseUrl$path'), headers: _headers(auth: auth)),
      path,
      auth: auth,
    );
    final duration = DateTime.now().millisecondsSinceEpoch - start;
    PerformanceMonitor.instance.recordApiCall('GET $path', duration, isError: res.statusCode >= 400);
    if (res.statusCode != 200) {
      throw ApiException(_extractError(jsonDecode(res.body)), statusCode: res.statusCode);
    }
    return parseListResponse(jsonDecode(res.body), path);
  }

  /// Tolerar `[...]` o `{data: [...]}` según el contrato del endpoint.
  @visibleForTesting
  static List<dynamic> parseListResponse(dynamic data, String path) {
    if (data is List) return data;
    if (data is Map && data['data'] is List) return data['data'] as List<dynamic>;
    LoggerService.instance.error('HttpClient: invalid list response for $path');
    throw Exception('Respuesta inv\u00e1lida del servidor');
  }

  /// Variante tolerante para pantallas de solo lectura: acepta `[...]` o
  /// `{data: [...]}` y devuelve lista vacía si el formato no es reconocible
  /// (en lugar de lanzar). Evita pantallas rotas ante respuestas inesperadas.
  static List<dynamic> parseListLenient(dynamic data) {
    if (data is List) return data;
    if (data is Map && data['data'] is List) return data['data'] as List<dynamic>;
    return [];
  }

  static Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    bool auth = false,
    bool idempotent = false,
  }) async {
    final start = DateTime.now().millisecondsSinceEpoch;
    await _waitForNetwork();
    final res = await _execute(
      () {
        final headers = _headers(auth: auth);
        if (idempotent) headers['X-Idempotency-Key'] = _newIdempotencyKey();
        return http.post(
          Uri.parse('$baseUrl$path'),
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        );
      },
      path,
      auth: auth,
    );
    final duration = DateTime.now().millisecondsSinceEpoch - start;
    PerformanceMonitor.instance.recordApiCall('POST $path', duration, isError: res.statusCode >= 400);
    return _handleResponse(res);
  }

  /// Clave de idempotencia para los endpoints que la exigen
  /// (POST /api/trips/request, complete y finalize).
  static String _newIdempotencyKey() {
    final rng = Random.secure();
    const chars = '0123456789abcdef';
    final sb = StringBuffer();
    for (int i = 0; i < 32; i++) {
      sb.write(chars[rng.nextInt(16)]);
    }
    return sb.toString();
  }

  static Future<Map<String, dynamic>> put(String path, {Map<String, dynamic>? body, bool auth = false}) async {
    final start = DateTime.now().millisecondsSinceEpoch;
    await _waitForNetwork();
    final res = await _execute(
      () => http.put(
        Uri.parse('$baseUrl$path'),
        headers: _headers(auth: auth),
        body: body != null ? jsonEncode(body) : null,
      ),
      path,
      auth: auth,
    );
    final duration = DateTime.now().millisecondsSinceEpoch - start;
    PerformanceMonitor.instance.recordApiCall('PUT $path', duration, isError: res.statusCode >= 400);
    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> delete(String path, {bool auth = false}) async {
    final start = DateTime.now().millisecondsSinceEpoch;
    await _waitForNetwork();
    final res = await _execute(
      () => http.delete(Uri.parse('$baseUrl$path'), headers: _headers(auth: auth)),
      path,
      auth: auth,
    );
    final duration = DateTime.now().millisecondsSinceEpoch - start;
    PerformanceMonitor.instance.recordApiCall('DELETE $path', duration, isError: res.statusCode >= 400);
    return _handleResponse(res);
  }

  /// Descarga binaria (ej. PDF de ganancias) con el mismo manejo de token,
  /// refresh y timeout que el resto de peticiones.
  static Future<List<int>> getBytes(String path, {bool auth = false}) async {
    final start = DateTime.now().millisecondsSinceEpoch;
    await _waitForNetwork();
    final res = await _execute(
      () => http.get(Uri.parse('$baseUrl$path'), headers: _headers(auth: auth)),
      path,
      auth: auth,
    );
    final duration = DateTime.now().millisecondsSinceEpoch - start;
    PerformanceMonitor.instance.recordApiCall('GET $path', duration, isError: res.statusCode >= 400);
    if (res.statusCode != 200) {
      dynamic data;
      try {
        data = jsonDecode(res.body);
      } catch (_) {
        data = null;
      }
      final code = data is Map ? data['code'] as String? : null;
      throw ApiException(_extractError(data), statusCode: res.statusCode, code: code);
    }
    return res.bodyBytes.toList();
  }

  static Future<Map<String, dynamic>> uploadFile(
    String path, {
    required List<int> bytes,
    required String filename,
    required String fieldName,
    bool auth = false,
  }) async {
    final start = DateTime.now().millisecondsSinceEpoch;
    await _waitForNetwork();
    final res = await _execute(() async {
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'));
      if (auth && ApiClient.instance.token != null) {
        request.headers['Authorization'] = 'Bearer ${ApiClient.instance.token}';
      }
      request.files.add(http.MultipartFile.fromBytes(fieldName, bytes, filename: filename));
      final streamed = await request.send().timeout(_timeout);
      return http.Response.fromStream(streamed).timeout(_timeout);
    }, path, auth: auth);
    final duration = DateTime.now().millisecondsSinceEpoch - start;
    PerformanceMonitor.instance.recordApiCall('UPLOAD $path', duration, isError: res.statusCode >= 400);
    return _handleResponse(res);
  }

  static Future<void> _waitForNetwork() async {
    if (!NetworkMonitorService.instance.isOnline) {
      LoggerService.instance.info('HttpClient: waiting for network connection');
      await NetworkMonitorService.instance.waitForConnection();
    }
  }

  static Map<String, dynamic> _handleResponse(http.Response res) {
    if (res.statusCode == 204) {
      return <String, dynamic>{'statusCode': 204};
    }
    dynamic data;
    try {
      data = jsonDecode(res.body);
    } catch (e) {
      LoggerService.instance.error('HttpClient: invalid JSON response ${res.statusCode}', e);
      throw Exception('Error de conexi\u00f3n. Intenta de nuevo.');
    }
    if (res.statusCode != 200 && res.statusCode != 201) {
      final error = _extractError(data);
      final code = data is Map ? data['code'] as String? : null;
      LoggerService.instance.error('HttpClient: ${res.statusCode} ${res.request?.url.path ?? ''} - $error');
      throw ApiException(error, statusCode: res.statusCode, code: code);
    }
    return data as Map<String, dynamic>;
  }

  static String _extractError(dynamic data) {
    if (data is Map) {
      if (data['message'] != null) return data['message'] as String;
      final errors = data['errors'];
      if (errors is List && errors.isNotEmpty) {
        return (errors[0] as Map<String, dynamic>)['message'] as String? ?? 'Error del servidor';
      }
      if (data['error'] != null) return data['error'] as String;
    }
    return 'Error del servidor';
  }
}

/// Error de API que conserva el código de estado HTTP. `toString()` mantiene
/// el formato `Exception: <mensaje>` para no romper los `catch` existentes
/// que usan `replaceFirst('Exception: ', '')`.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? code;

  ApiException(this.message, {this.statusCode, this.code});

  @override
  String toString() => 'Exception: $message';
}
