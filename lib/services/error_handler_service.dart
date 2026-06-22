import 'dart:async';
import 'package:flutter/material.dart';
import 'logger_service.dart';

enum ErrorCategory { network, gps, socket, map, auth, general }

class ErrorHandlerService {
  static final ErrorHandlerService instance = ErrorHandlerService._();
  ErrorHandlerService._();

  bool _initialized = false;
  final StreamController<ErrorEvent> _errorCtrl = StreamController<ErrorEvent>.broadcast();
  Stream<ErrorEvent> get onError => _errorCtrl.stream;

  void init() {
    if (_initialized) return;
    _initialized = true;

    LoggerService.instance.info('ErrorHandlerService initialized');
  }

  void handleError(
    dynamic error,
    StackTrace? stack, {
    ErrorCategory category = ErrorCategory.general,
    String? message,
    bool fatal = false,
  }) {
    final event = ErrorEvent(
      error: error,
      stack: stack,
      category: category,
      message: message ?? _defaultMessage(category),
      fatal: fatal,
      timestamp: DateTime.now(),
    );

    LoggerService.instance.error(
      '[${category.name.toUpperCase()}] ${event.message}',
      error,
      stack,
    );

    if (!_errorCtrl.isClosed) {
      _errorCtrl.add(event);
    }

    if (fatal) {
      _handleFatalError(event);
    }
  }

  Future<T?> safeAsync<T>(
    Future<T> Function() fn, {
    ErrorCategory category = ErrorCategory.general,
    String? message,
    T? fallback,
  }) async {
    try {
      return await fn();
    } catch (e, s) {
      handleError(e, s, category: category, message: message);
      return fallback;
    }
  }

  T safeSync<T>(
    T Function() fn, {
    ErrorCategory category = ErrorCategory.general,
    String? message,
    required T fallback,
  }) {
    try {
      return fn();
    } catch (e, s) {
      handleError(e, s, category: category, message: message);
      return fallback;
    }
  }

  Stream<T> safeStream<T>(
    Stream<T> stream, {
    ErrorCategory category = ErrorCategory.general,
    String? message,
  }) {
    return stream.handleError((e, s) {
      handleError(e, s, category: category, message: message);
    });
  }

  void _handleFatalError(ErrorEvent event) {
    LoggerService.instance.error(
      'FATAL: ${event.message} - attempting recovery',
      event.error,
      event.stack,
    );
  }

  String _defaultMessage(ErrorCategory category) {
    switch (category) {
      case ErrorCategory.network:
        return 'Error de conexi\u00f3n. Verifica tu internet.';
      case ErrorCategory.gps:
        return 'Error de ubicaci\u00f3n. Verifica tu GPS.';
      case ErrorCategory.socket:
        return 'Error de conexi\u00f3n en tiempo real. Reintentando...';
      case ErrorCategory.map:
        return 'Error al cargar el mapa.';
      case ErrorCategory.auth:
        return 'Error de autenticaci\u00f3n. Inicia sesi\u00f3n nuevamente.';
      case ErrorCategory.general:
        return 'Ocurri\u00f3 un error inesperado.';
    }
  }

  void showErrorSnackBar(
    BuildContext context, {
    String? message,
    ErrorCategory category = ErrorCategory.general,
    VoidCallback? onRetry,
  }) {
    if (!context.mounted) return;

    final msg = message ?? _defaultMessage(category);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              _iconForCategory(category),
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: _colorForCategory(category),
        behavior: SnackBarBehavior.floating,
        action: onRetry != null
            ? SnackBarAction(
                label: 'Reintentar',
                textColor: Colors.white,
                onPressed: onRetry,
              )
            : null,
        duration: Duration(seconds: onRetry != null ? 10 : 4),
      ),
    );
  }

  Future<void> showErrorDialog(
    BuildContext context, {
    String? title,
    String? message,
    ErrorCategory category = ErrorCategory.general,
    VoidCallback? onRetry,
  }) async {
    if (!context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          _iconForCategory(category),
          size: 48,
          color: _colorForCategory(category),
        ),
        title: Text(title ?? 'Error'),
        content: Text(message ?? _defaultMessage(category)),
        actions: [
          if (onRetry != null)
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                onRetry();
              },
              child: const Text('Reintentar'),
            ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  IconData _iconForCategory(ErrorCategory category) {
    switch (category) {
      case ErrorCategory.network:
        return Icons.wifi_off;
      case ErrorCategory.gps:
        return Icons.location_off;
      case ErrorCategory.socket:
        return Icons.sync_disabled;
      case ErrorCategory.map:
        return Icons.map;
      case ErrorCategory.auth:
        return Icons.lock_outline;
      case ErrorCategory.general:
        return Icons.error_outline;
    }
  }

  Color _colorForCategory(ErrorCategory category) {
    switch (category) {
      case ErrorCategory.network:
        return Colors.orange.shade700;
      case ErrorCategory.gps:
        return Colors.amber.shade700;
      case ErrorCategory.socket:
        return Colors.blueGrey;
      case ErrorCategory.map:
        return Colors.teal.shade700;
      case ErrorCategory.auth:
        return Colors.red.shade700;
      case ErrorCategory.general:
        return Colors.grey.shade700;
    }
  }

  void dispose() {
    _errorCtrl.close();
  }
}

class ErrorEvent {
  final dynamic error;
  final StackTrace? stack;
  final ErrorCategory category;
  final String message;
  final bool fatal;
  final DateTime timestamp;

  ErrorEvent({
    required this.error,
    this.stack,
    required this.category,
    required this.message,
    required this.fatal,
    required this.timestamp,
  });
}
