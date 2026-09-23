import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;
import '../../core/environment.dart';
import '../api_client.dart';
import '../error_handler_service.dart';
import '../logger_service.dart';
import '../network_monitor_service.dart';
import '../performance_monitor.dart';
import '../server_clock.dart';
import '../session_events.dart';

class HttpClient {
  static String get baseUrl => Environment.baseUrl;

  /// Timeout aplicado a todas las peticiones para evitar esperas infinitas.
  static const Duration _timeout = Duration(seconds: 20);

  /// Timeout de subidas (fotos/documentos en redes móviles lentas).
  static const Duration _uploadTimeout = Duration(seconds: 60);

  /// Tamaño máximo por defecto de una subida (5 MB, igual que el backend).
  static const int defaultMaxUploadBytes = 5 * 1024 * 1024;

  /// `true` cuando el código corre en el isolate del servicio en segundo plano
  /// (flutter_background_service). En ese isolate:
  ///  - no se espera a NetworkMonitorService (no está inicializado),
  ///  - NUNCA se renueva el token (los refresh tokens son de un solo uso y el
  ///    isolate principal los rota): ante 401 se relee el token de
  ///    SharedPreferences y se reintenta una vez.
  static bool isBackgroundIsolate = false;

  /// Evita refresh en cascada cuando varias peticiones reciben 401 a la vez:
  /// todas comparten el mismo Future de renovación de sesión.
  static Future<bool>? _refreshing;

  /// Renueva la sesión compartiendo una única petición en vuelo.
  /// Devuelve `true` si hay token nuevo, `false` si el refresh token es
  /// inválido (sesión terminada; los tokens ya se limpiaron). Lanza ante
  /// errores transitorios (red, 429, 5xx) conservando la sesión.
  static Future<bool> refreshSessionShared() {
    return _refreshing ??= _refreshSession().whenComplete(() => _refreshing = null);
  }

  /// Ejecuta la petición; ante 401 con auth intenta renovar el token y
  /// reintenta una vez. Si el refresh falla, emite sesión expirada.
  /// Ante 403 `CUENTA_SUSPENDIDA` cierra la sesión y emite suspensión.
  static Future<http.Response> _execute(
    Future<http.Response> Function() request,
    String path, {
    required bool auth,
    Duration timeout = _timeout,
  }) async {
    final tokenUsed = ApiClient.instance.token;
    var res = await _send(request, timeout);
    if (res.statusCode == 401 && auth) {
      if (isBackgroundIsolate) {
        // El isolate principal pudo haber rotado los tokens: releerlos.
        await ApiClient.instance.reloadTokens();
        final current = ApiClient.instance.token;
        if (current != null && current != tokenUsed) {
          res = await _send(request, timeout);
        }
      } else if (ApiClient.instance.token != null &&
          ApiClient.instance.token != tokenUsed) {
        // Otra petición ya renovó el token mientras esta volaba.
        res = await _send(request, timeout);
      } else {
        final ok = await refreshSessionShared();
        if (ok) {
          LoggerService.instance.info('HttpClient: token refrescado, reintentando $path');
          res = await _send(request, timeout);
        } else {
          LoggerService.instance.error('HttpClient: refresh falló, sesión expirada');
          ErrorHandlerService.instance.emitSessionExpired();
          throw ApiException(
            'Sesión expirada. Inicia sesión nuevamente.',
            statusCode: 401,
            code: 'SESION_EXPIRADA',
          );
        }
      }
    }
    if (res.statusCode == 403 && auth) {
      await _checkSuspended(res);
    }
    return res;
  }

  /// Si la respuesta es 403 `CUENTA_SUSPENDIDA`: limpia la sesión, emite el
  /// evento global y lanza [ApiException].
  static Future<void> _checkSuspended(http.Response res) async {
    final data = _tryDecode(res.body);
    if (data is! Map || data['code']?.toString() != 'CUENTA_SUSPENDIDA') return;
    final message = _extractError(data, res.statusCode);
    LoggerService.instance.warning('HttpClient: cuenta suspendida');
    await ApiClient.instance.clearTokens();
    SessionEvents.instance.emit(SessionEvent(SessionEventType.suspended, message));
    throw ApiException(message, statusCode: 403, code: 'CUENTA_SUSPENDIDA');
  }

  /// Traduce fallos de red a un ApiException con mensaje legible para el usuario
  /// (en vez de mostrar "TimeoutException after..." o "ClientException: ...").
  static Future<http.Response> _send(
    Future<http.Response> Function() request, [
    Duration timeout = _timeout,
  ]) async {
    try {
      final res = await request().timeout(timeout);
      ServerClock.registrarFecha(res.headers['date']);
      return res;
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
    } on ApiException catch (e) {
      // Sólo un rechazo explícito del refresh token termina la sesión.
      if (ApiClient.isRefreshRejection(e)) return false;
      rethrow;
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
    final data = _tryDecode(res.body);
    if (res.statusCode != 200) {
      throw ApiException(
        _extractError(data, res.statusCode),
        statusCode: res.statusCode,
        code: data is Map ? data['code']?.toString() : null,
        data: data is Map ? Map<String, dynamic>.from(data) : null,
      );
    }
    return parseListResponse(data, path);
  }

  /// Tolerar `[...]` o `{data: [...]}` según el contrato del endpoint.
  @visibleForTesting
  static List<dynamic> parseListResponse(dynamic data, String path) {
    if (data is List) return data;
    if (data is Map && data['data'] is List) return data['data'] as List<dynamic>;
    LoggerService.instance.error('HttpClient: invalid list response for $path');
    throw Exception('Respuesta inválida del servidor');
  }

  /// Variante tolerante para pantallas de solo lectura: acepta `[...]` o
  /// `{data: [...]}` y devuelve lista vacía si el formato no es reconocible
  /// (en lugar de lanzar). Evita pantallas rotas ante respuestas inesperadas.
  static List<dynamic> parseListLenient(dynamic data) {
    if (data is List) return data;
    if (data is Map && data['data'] is List) return data['data'] as List<dynamic>;
    return [];
  }

  /// POST. Con `idempotent: true` se envía `X-Idempotency-Key`: si se pasa
  /// [idempotencyKey] se usa esa (una por acción del usuario, para que los
  /// reintentos manuales no dupliquen); si no, se genera una por llamada. La
  /// misma clave se reutiliza en el reintento tras renovar el token.
  static Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    bool auth = false,
    bool idempotent = false,
    String? idempotencyKey,
  }) async {
    final start = DateTime.now().millisecondsSinceEpoch;
    await _waitForNetwork();
    final key = (idempotent || idempotencyKey != null)
        ? (idempotencyKey ?? newIdempotencyKey())
        : null;
    final res = await _execute(
      () {
        final headers = _headers(auth: auth);
        if (key != null) headers['X-Idempotency-Key'] = key;
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
  /// (POST /api/trips/request, reserve, complete y finalize). Las pantallas
  /// pueden generar una por acción del usuario y reutilizarla en reintentos.
  static String newIdempotencyKey() {
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
      final data = _tryDecode(res.body);
      final code = data is Map ? data['code']?.toString() : null;
      throw ApiException(_extractError(data, res.statusCode), statusCode: res.statusCode, code: code);
    }
    return res.bodyBytes.toList();
  }

  /// Sube un archivo multipart. Rechaza localmente archivos mayores a
  /// [maxBytes] (por defecto 5 MB) con un [ApiException] legible, y envía el
  /// Content-Type según la extensión de [filename].
  static Future<Map<String, dynamic>> uploadFile(
    String path, {
    required List<int> bytes,
    required String filename,
    required String fieldName,
    bool auth = false,
    int maxBytes = defaultMaxUploadBytes,
    String method = 'POST',
    Map<String, String>? fields,
  }) async {
    if (bytes.length > maxBytes) {
      final mb = (maxBytes / (1024 * 1024)).round();
      throw ApiException(
        'La imagen supera $mb MB. Intenta con otra foto.',
        statusCode: 413,
        code: 'ARCHIVO_MUY_GRANDE',
      );
    }
    final contentType = mediaTypeForFilename(filename);
    final start = DateTime.now().millisecondsSinceEpoch;
    await _waitForNetwork();
    final res = await _execute(() async {
      final request = http.MultipartRequest(method, Uri.parse('$baseUrl$path'));
      if (fields != null) request.fields.addAll(fields);
      if (auth && ApiClient.instance.token != null) {
        request.headers['Authorization'] = 'Bearer ${ApiClient.instance.token}';
      }
      request.files.add(http.MultipartFile.fromBytes(
        fieldName,
        bytes,
        filename: filename,
        contentType: contentType,
      ));
      final streamed = await request.send();
      return http.Response.fromStream(streamed);
    }, path, auth: auth, timeout: _uploadTimeout);
    final duration = DateTime.now().millisecondsSinceEpoch - start;
    PerformanceMonitor.instance.recordApiCall('UPLOAD $path', duration, isError: res.statusCode >= 400);
    return _handleResponse(res);
  }

  /// Content-Type según la extensión del archivo (el backend valida el tipo).
  @visibleForTesting
  static MediaType mediaTypeForFilename(String filename) {
    final dot = filename.lastIndexOf('.');
    final ext = dot >= 0 ? filename.substring(dot + 1).toLowerCase() : '';
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      case 'png':
        return MediaType('image', 'png');
      case 'gif':
        return MediaType('image', 'gif');
      case 'webp':
        return MediaType('image', 'webp');
      case 'heic':
        return MediaType('image', 'heic');
      case 'heif':
        return MediaType('image', 'heif');
      case 'pdf':
        return MediaType('application', 'pdf');
      default:
        return MediaType('application', 'octet-stream');
    }
  }

  static Future<void> _waitForNetwork() async {
    // En el isolate de segundo plano NetworkMonitorService no está iniciado.
    if (isBackgroundIsolate) return;
    if (!NetworkMonitorService.instance.isOnline) {
      LoggerService.instance.info('HttpClient: waiting for network connection');
      await NetworkMonitorService.instance.waitForConnection();
    }
  }

  static dynamic _tryDecode(String body) {
    if (body.isEmpty) return null;
    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }

  static Map<String, dynamic> _handleResponse(http.Response res) {
    if (res.statusCode == 204) {
      return <String, dynamic>{'statusCode': 204};
    }
    final data = _tryDecode(res.body);
    if (res.statusCode != 200 && res.statusCode != 201) {
      final error = _extractError(data, res.statusCode);
      final code = data is Map ? data['code']?.toString() : null;
      LoggerService.instance.error('HttpClient: ${res.statusCode} ${res.request?.url.path ?? ''} - $error');
      throw ApiException(
        error,
        statusCode: res.statusCode,
        code: code,
        data: data is Map ? Map<String, dynamic>.from(data) : null,
      );
    }
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is List) return <String, dynamic>{'data': data};
    if (res.body.trim().isEmpty) return <String, dynamic>{};
    LoggerService.instance.error('HttpClient: invalid JSON response ${res.statusCode}');
    throw ApiException('Respuesta inválida del servidor. Intenta de nuevo.', statusCode: res.statusCode);
  }

  /// Extrae el mensaje de error de `{message}`, `{errors:[{message}]}` o
  /// `{error}`. Tolera tipos inesperados y cuerpos no JSON.
  @visibleForTesting
  static String extractError(dynamic data, [int? statusCode]) => _extractError(data, statusCode);

  static String _extractError(dynamic data, [int? statusCode]) {
    String? nonEmpty(dynamic v) {
      if (v == null) return null;
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    }

    if (data is Map) {
      final message = nonEmpty(data['message']);
      if (message != null) return message;
      final errors = data['errors'];
      if (errors is List && errors.isNotEmpty) {
        final first = errors.first;
        final msg = first is Map ? nonEmpty(first['message']) : nonEmpty(first);
        if (msg != null) return msg;
      }
      final error = data['error'];
      if (error is Map) {
        final msg = nonEmpty(error['message']);
        if (msg != null) return msg;
      } else {
        final msg = nonEmpty(error);
        if (msg != null) return msg;
      }
    }
    return _genericMessage(statusCode);
  }

  static String _genericMessage(int? statusCode) {
    if (statusCode == null) return 'Error del servidor';
    if (statusCode == 429) {
      return 'Demasiadas solicitudes. Espera un momento e intenta de nuevo. ($statusCode)';
    }
    if (statusCode >= 500) {
      return 'El servidor no está disponible en este momento. Intenta más tarde. ($statusCode)';
    }
    return 'Error del servidor ($statusCode)';
  }
}

/// Error de API que conserva el código de estado HTTP. `toString()` mantiene
/// el formato `Exception: <mensaje>` para no romper los `catch` existentes
/// que usan `replaceFirst('Exception: ', '')`.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? code;

  /// Cuerpo completo del error (p. ej. `distanciaKm` de CONDUCTOR_CERCA).
  final Map<String, dynamic>? data;

  ApiException(this.message, {this.statusCode, this.code, this.data});

  @override
  String toString() => 'Exception: $message';
}
