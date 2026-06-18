import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'logger_service.dart';

class NetworkMonitorService {
  static final NetworkMonitorService instance = NetworkMonitorService._();
  NetworkMonitorService._();

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _connectionCtrl = StreamController<bool>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool _isOnline = true;
  bool _initialized = false;

  Stream<bool> get onConnectionChanged => _connectionCtrl.stream;
  bool get isOnline => _isOnline;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final results = await _connectivity.checkConnectivity();
      _isOnline = !results.contains(ConnectivityResult.none);
      _subscription = _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);
    } catch (e) {
      LoggerService.instance.error('NetworkMonitorService.init error', e);
      _isOnline = true;
    }
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final wasOnline = _isOnline;
    _isOnline = !results.contains(ConnectivityResult.none);

    if (wasOnline != _isOnline) {
      LoggerService.instance.info('Network status changed: online=$_isOnline');
      _connectionCtrl.add(_isOnline);
    }
  }

  Future<bool> waitForConnection({Duration timeout = const Duration(seconds: 30)}) async {
    if (_isOnline) return true;
    try {
      await onConnectionChanged.timeout(timeout).firstWhere((online) => online);
      return true;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    _subscription?.cancel();
    _connectionCtrl.close();
  }
}
