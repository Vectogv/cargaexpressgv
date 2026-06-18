import 'dart:async';
import 'dart:math';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'api_client.dart';
import 'logger_service.dart';
import 'network_monitor_service.dart';

class SocketServiceClient {
  static final SocketServiceClient instance = SocketServiceClient._();
  SocketServiceClient._();

  IO.Socket? _socket;
  bool _connected = false;
  bool _initialized = false;

  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 50;
  Timer? _reconnectTimer;
  StreamSubscription<bool>? _networkSub;

  final _tripStatusCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _driverLocationCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _newOfferCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _offerAcceptedCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _offerRejectedCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _messageCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _notificationCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _tripAcceptedCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _tripCompletedCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _tripCancelledCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _finalizeRequestCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _finalizeResponseCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _typingStartCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _typingStopCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _messageReadCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionCtrl = StreamController<bool>.broadcast();

  // Admin real-time streams
  final _adminStatsCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _adminDriverLocationCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _adminClientLocationCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _adminDisputeCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _adminCancellationCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _adminEmergencyCtrl = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onTripStatus => _tripStatusCtrl.stream;
  Stream<Map<String, dynamic>> get onDriverLocation => _driverLocationCtrl.stream;
  Stream<Map<String, dynamic>> get onNewOffer => _newOfferCtrl.stream;
  Stream<Map<String, dynamic>> get onOfferAccepted => _offerAcceptedCtrl.stream;
  Stream<Map<String, dynamic>> get onOfferRejected => _offerRejectedCtrl.stream;
  Stream<Map<String, dynamic>> get onMessage => _messageCtrl.stream;
  Stream<Map<String, dynamic>> get onNotification => _notificationCtrl.stream;
  Stream<Map<String, dynamic>> get onTripAccepted => _tripAcceptedCtrl.stream;
  Stream<Map<String, dynamic>> get onTripCompleted => _tripCompletedCtrl.stream;
  Stream<Map<String, dynamic>> get onTripCancelled => _tripCancelledCtrl.stream;
  Stream<Map<String, dynamic>> get onFinalizeRequest => _finalizeRequestCtrl.stream;
  Stream<Map<String, dynamic>> get onFinalizeResponse => _finalizeResponseCtrl.stream;
  Stream<Map<String, dynamic>> get onTypingStart => _typingStartCtrl.stream;
  Stream<Map<String, dynamic>> get onTypingStop => _typingStopCtrl.stream;
  Stream<Map<String, dynamic>> get onMessageRead => _messageReadCtrl.stream;
  Stream<Map<String, dynamic>> get onAdminStats => _adminStatsCtrl.stream;
  Stream<Map<String, dynamic>> get onAdminDriverLocation => _adminDriverLocationCtrl.stream;
  Stream<Map<String, dynamic>> get onAdminClientLocation => _adminClientLocationCtrl.stream;
  Stream<Map<String, dynamic>> get onAdminDispute => _adminDisputeCtrl.stream;
  Stream<Map<String, dynamic>> get onAdminCancellation => _adminCancellationCtrl.stream;
  Stream<Map<String, dynamic>> get onAdminEmergency => _adminEmergencyCtrl.stream;

  Stream<bool> get onConnection => _connectionCtrl.stream;

  bool get isConnected => _connected;

  int _chatUnreadCount = 0;
  final _chatUnreadCtrl = StreamController<int>.broadcast();

  int get chatUnreadCount => _chatUnreadCount;
  Stream<int> get onChatUnreadChange => _chatUnreadCtrl.stream;

  void resetChatUnread() {
    _chatUnreadCount = 0;
    _chatUnreadCtrl.add(0);
  }

  void _incrementChatUnread() {
    _chatUnreadCount++;
    _chatUnreadCtrl.add(_chatUnreadCount);
  }

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    _networkSub = NetworkMonitorService.instance.onConnectionChanged.listen((online) {
      if (online && !_connected) {
        LoggerService.instance.info('SocketServiceClient: network restored, reconnecting');
        _scheduleReconnect();
      }
    });

    _connect();
  }

  void _connect() {
    final token = ApiClient.instance.token;
    final userId = ApiClient.instance.userId;
    final baseUrl = ApiClient.baseUrl;

    if (token == null) {
      LoggerService.instance.warning('SocketServiceClient: no token available');
      return;
    }

    try {
      _socket?.dispose();
      _socket = IO.io(baseUrl, <String, dynamic>{
        'transports': ['websocket'],
        'query': {'token': token},
        'forceNew': true,
        'reconnection': false,
      });

      _socket!.on('connect', (_) {
        _connected = true;
        _reconnectAttempts = 0;
        _connectionCtrl.add(true);
        LoggerService.instance.info('SocketServiceClient connected');
        if (userId != null) {
          _socket!.emit('join:client', {'userId': userId});
        }
        if (ApiClient.instance.rol == 'admin') {
          _socket!.emit('admin:join', {});
        }
      });

      _socket!.on('disconnect', (_) {
        _connected = false;
        _connectionCtrl.add(false);
        LoggerService.instance.warning('SocketServiceClient disconnected');
        _scheduleReconnect();
      });

      _socket!.on('connect_error', (error) {
        LoggerService.instance.error('SocketServiceClient connect_error', error);
        _connected = false;
        _connectionCtrl.add(false);
        _scheduleReconnect();
      });

      _socket!.on('reconnect_attempt', (_) {
        LoggerService.instance.debug('SocketServiceClient reconnect_attempt');
      });

      _socket!.on('trip:status', (data) {
        if (data is Map) _tripStatusCtrl.add(Map<String, dynamic>.from(data));
      });

      _socket!.on('driver:location', (data) {
        if (data is Map) _driverLocationCtrl.add(Map<String, dynamic>.from(data));
      });

      _socket!.on('new:offer', (data) {
        if (data is Map) _newOfferCtrl.add(Map<String, dynamic>.from(data));
      });

      _socket!.on('offer:accepted', (data) {
        if (data is Map) _offerAcceptedCtrl.add(Map<String, dynamic>.from(data));
      });

      _socket!.on('offer:rejected', (data) {
        if (data is Map) _offerRejectedCtrl.add(Map<String, dynamic>.from(data));
      });

      _socket!.on('message:new', (data) {
        if (data is Map) {
          _messageCtrl.add(Map<String, dynamic>.from(data));
          final senderId = (data as Map)['senderId']?.toString();
          if (senderId != null && senderId != ApiClient.instance.userId) {
            _incrementChatUnread();
          }
        }
      });

      _socket!.on('notification:new', (data) {
        if (data is Map) _notificationCtrl.add(Map<String, dynamic>.from(data));
      });

      _socket!.on('notification:read', (data) {
        if (data is Map) _notificationCtrl.add(Map<String, dynamic>.from(data));
      });

      _socket!.on('notification:delete', (data) {
        if (data is Map) _notificationCtrl.add(Map<String, dynamic>.from(data));
      });

      _socket!.on('trip:accepted', (data) {
        if (data is Map) _tripAcceptedCtrl.add(Map<String, dynamic>.from(data));
      });

      _socket!.on('trip:completed', (data) {
        if (data is Map) _tripCompletedCtrl.add(Map<String, dynamic>.from(data));
      });

      _socket!.on('trip:cancelled', (data) {
        if (data is Map) _tripCancelledCtrl.add(Map<String, dynamic>.from(data));
      });

      _socket!.on('trip:finalize_request', (data) {
        if (data is Map) _finalizeRequestCtrl.add(Map<String, dynamic>.from(data));
      });

      _socket!.on('trip:finalize_response', (data) {
        if (data is Map) _finalizeResponseCtrl.add(Map<String, dynamic>.from(data));
      });

      _socket!.on('typing:start', (data) {
        if (data is Map) _typingStartCtrl.add(Map<String, dynamic>.from(data));
      });

      _socket!.on('typing:stop', (data) {
        if (data is Map) _typingStopCtrl.add(Map<String, dynamic>.from(data));
      });

      _socket!.on('message:read', (data) {
        if (data is Map) _messageReadCtrl.add(Map<String, dynamic>.from(data));
      });

      _socket!.on('admin:stats', (data) {
        if (data is Map) _adminStatsCtrl.add(Map<String, dynamic>.from(data));
      });

      _socket!.on('admin:driver:location', (data) {
        if (data is Map) _adminDriverLocationCtrl.add(Map<String, dynamic>.from(data));
      });

      _socket!.on('admin:client:location', (data) {
        if (data is Map) _adminClientLocationCtrl.add(Map<String, dynamic>.from(data));
      });

      _socket!.on('admin:dispute:new', (data) {
        if (data is Map) _adminDisputeCtrl.add(Map<String, dynamic>.from(data));
      });

      _socket!.on('admin:cancellation', (data) {
        if (data is Map) _adminCancellationCtrl.add(Map<String, dynamic>.from(data));
      });

      _socket!.on('admin:emergency', (data) {
        if (data is Map) _adminEmergencyCtrl.add(Map<String, dynamic>.from(data));
      });
    } catch (e) {
      LoggerService.instance.error('SocketServiceClient._connect error', e);
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      LoggerService.instance.warning('SocketServiceClient: max reconnect attempts reached');
      return;
    }

    if (!NetworkMonitorService.instance.isOnline) {
      LoggerService.instance.debug('SocketServiceClient: waiting for network before reconnecting');
      return;
    }

    _reconnectAttempts++;
    final delay = Duration(milliseconds: min(1000 * pow(2, _reconnectAttempts).toInt(), 30000));
    LoggerService.instance.debug('SocketServiceClient: scheduling reconnect #$_reconnectAttempts in ${delay.inSeconds}s');

    _reconnectTimer = Timer(delay, () {
      if (ApiClient.instance.token != null) {
        _connect();
      }
    });
  }

  void emit(String event, Map<String, dynamic> data) {
    if (_socket != null && _connected) {
      _socket!.emit(event, data);
    } else {
      LoggerService.instance.warning('SocketServiceClient: cannot emit $event, not connected');
    }
  }

  void reconnect() {
    _reconnectAttempts = 0;
    _socket?.disconnect();
    _socket?.connect();
  }

  void forceReconnect() {
    _reconnectAttempts = 0;
    _reconnectTimer?.cancel();
    _connect();
  }

  void dispose() {
    _reconnectTimer?.cancel();
    _networkSub?.cancel();
    _socket?.disconnect();
    _socket?.dispose();
    _tripStatusCtrl.close();
    _driverLocationCtrl.close();
    _newOfferCtrl.close();
    _offerAcceptedCtrl.close();
    _offerRejectedCtrl.close();
    _messageCtrl.close();
    _notificationCtrl.close();
    _tripAcceptedCtrl.close();
    _tripCompletedCtrl.close();
    _tripCancelledCtrl.close();
    _finalizeRequestCtrl.close();
    _finalizeResponseCtrl.close();
    _typingStartCtrl.close();
    _typingStopCtrl.close();
    _messageReadCtrl.close();
    _chatUnreadCtrl.close();
    _adminStatsCtrl.close();
    _adminDriverLocationCtrl.close();
    _adminClientLocationCtrl.close();
    _adminDisputeCtrl.close();
    _adminCancellationCtrl.close();
    _adminEmergencyCtrl.close();
    _connectionCtrl.close();
  }
}
