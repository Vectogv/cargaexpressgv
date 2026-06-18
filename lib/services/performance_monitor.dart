import 'dart:async';
import 'dart:collection';
import 'logger_service.dart';

class _MetricEntry {
  final String label;
  final int durationMs;
  final DateTime timestamp;
  final bool isError;

  _MetricEntry({
    required this.label,
    required this.durationMs,
    required this.timestamp,
    this.isError = false,
  });
}

class PerformanceMonitor {
  static final PerformanceMonitor instance = PerformanceMonitor._();
  PerformanceMonitor._();

  final Queue<_MetricEntry> _metrics = Queue();
  static const int _maxMetrics = 500;
  final StreamController<List<_MetricEntry>> _metricsCtrl = StreamController<List<_MetricEntry>>.broadcast();

  Stream<List<_MetricEntry>> get onMetricsUpdate => _metricsCtrl.stream;

  final Map<String, int> _runningTimers = {};

  void startTimer(String label) {
    _runningTimers[label] = DateTime.now().millisecondsSinceEpoch;
  }

  int? stopTimer(String label) {
    final start = _runningTimers.remove(label);
    if (start == null) return null;
    final duration = DateTime.now().millisecondsSinceEpoch - start;
    _addMetric(label, duration, false);
    return duration;
  }

  void recordApiCall(String endpoint, int durationMs, {bool isError = false}) {
    _addMetric('API: $endpoint', durationMs, isError);
  }

  void recordScreenLoad(String screenName, int durationMs) {
    _addMetric('Screen: $screenName', durationMs, false);
  }

  void recordOperation(String label, int durationMs) {
    _addMetric(label, durationMs, false);
  }

  void _addMetric(String label, int durationMs, bool isError) {
    final entry = _MetricEntry(label: label, durationMs: durationMs, timestamp: DateTime.now(), isError: isError);
    _metrics.add(entry);
    if (_metrics.length > _maxMetrics) _metrics.removeFirst();
    if (!_metricsCtrl.isClosed) _metricsCtrl.add(_metrics.toList());

    if (durationMs > 5000) {
      LoggerService.instance.warning('[PERF] Slow $label: ${durationMs}ms');
    }
    if (isError) {
      LoggerService.instance.error('[PERF] Error in $label: ${durationMs}ms');
    }
  }

  Map<String, dynamic> getSummary() {
    if (_metrics.isEmpty) return {'avg': 0, 'max': 0, 'count': 0, 'slowCount': 0};

    final total = _metrics.length;
    int sum = 0;
    int max = 0;
    int slow = 0;
    for (final m in _metrics) {
      sum += m.durationMs;
      if (m.durationMs > max) max = m.durationMs;
      if (m.durationMs > 5000) slow++;
    }

    return {
      'avg': (sum / total).round(),
      'max': max,
      'count': total,
      'slowCount': slow,
    };
  }

  List<Map<String, dynamic>> getRecentMetrics({int limit = 50}) {
    return _metrics.toList().reversed.take(limit).map((m) => {
      'label': m.label,
      'durationMs': m.durationMs,
      'timestamp': m.timestamp.toIso8601String(),
      'isError': m.isError,
    }).toList();
  }

  void dispose() {
    _metricsCtrl.close();
  }
}
