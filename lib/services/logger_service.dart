import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

enum LogLevel { debug, info, warning, error }

class LoggerService {
  static final LoggerService instance = LoggerService._();
  LoggerService._();

  final List<Map<String, dynamic>> _buffer = [];
  static const int _maxBuffer = 500;
  LogLevel _minLevel = LogLevel.debug;

  final StreamController<Map<String, dynamic>> _logCtrl = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onLog => _logCtrl.stream;

  // Alert thresholds
  int _errorCountInWindow = 0;
  DateTime _windowStart = DateTime.now();
  static const Duration _alertWindow = Duration(minutes: 5);
  static const int _maxErrorsPerWindow = 20;
  final StreamController<String> _alertCtrl = StreamController<String>.broadcast();
  Stream<String> get onAutoAlert => _alertCtrl.stream;

  void setMinLevel(LogLevel level) => _minLevel = level;

  void _log(LogLevel level, String message, [dynamic error, StackTrace? stack]) {
    if (level.index < _minLevel.index) return;

    final entry = {
      'timestamp': DateTime.now().toIso8601String(),
      'level': level.name,
      'message': message,
      if (error != null) 'error': error.toString(),
      if (stack != null) 'stack': stack.toString(),
    };
    _buffer.add(entry);
    if (_buffer.length > _maxBuffer) _buffer.removeAt(0);
    if (!_logCtrl.isClosed) _logCtrl.add(entry);

    final prefix = '[${level.name.toUpperCase()}]';
    if (level == LogLevel.error) {
      debugPrint('$prefix $message ${error ?? ''}');
      _recordInCrashlytics(error, stack);
      _checkAutoAlert();
    } else if (level == LogLevel.warning) {
      debugPrint('$prefix $message ${error ?? ''}');
    } else {
      debugPrint('$prefix $message');
    }
  }

  void _recordInCrashlytics(dynamic error, StackTrace? stack) {
    try {
      FirebaseCrashlytics.instance.recordError(error, stack ?? StackTrace.current);
    } catch (_) {}
  }

  void _checkAutoAlert() {
    final now = DateTime.now();
    if (now.difference(_windowStart) > _alertWindow) {
      _errorCountInWindow = 0;
      _windowStart = now;
    }
    _errorCountInWindow++;
    if (_errorCountInWindow >= _maxErrorsPerWindow) {
      _errorCountInWindow = 0;
      _windowStart = now;
      final msg = 'Alerta autom\u00e1tica: $_maxErrorsPerWindow errores en ${_alertWindow.inMinutes} minutos';
      debugPrint('[ALERT] $msg');
      if (!_alertCtrl.isClosed) _alertCtrl.add(msg);
    }
  }

  void debug(String message) => _log(LogLevel.debug, message);
  void info(String message) => _log(LogLevel.info, message);
  void warning(String message, [dynamic error]) => _log(LogLevel.warning, message, error);
  void error(String message, [dynamic error, StackTrace? stack]) => _log(LogLevel.error, message, error, stack);

  List<Map<String, dynamic>> getRecentLogs({int count = 50, LogLevel? minLevel}) {
    var logs = _buffer.reversed.take(count);
    if (minLevel != null) {
      logs = logs.where((e) => LogLevel.values.indexWhere((l) => l.name == e['level']) >= minLevel.index);
    }
    return List.unmodifiable(logs.toList());
  }

  int getLogCount({LogLevel? level}) {
    if (level == null) return _buffer.length;
    return _buffer.where((e) => e['level'] == level.name).length;
  }

  void clearLogs() => _buffer.clear();

  Future<void> exportLogsToFile() async {
    try {
      final file = File('${Directory.systemTemp.path}/cargaexpress_logs_${DateTime.now().millisecondsSinceEpoch}.txt');
      final content = _buffer.map((e) =>
        '[${e['timestamp']}] [${e['level']}] ${e['message']}${e['error'] != null ? ' | ${e['error']}' : ''}'
      ).join('\n');
      await file.writeAsString(content);
    } catch (_) {}
  }

  void dispose() {
    _logCtrl.close();
    _alertCtrl.close();
  }
}
