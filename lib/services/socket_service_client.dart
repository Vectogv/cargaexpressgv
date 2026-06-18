import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'api_client.dart';

class SocketServiceClient {
  static final SocketServiceClient instance = SocketServiceClient._();
  SocketServiceClient._();

  IO.Socket? _socket;
  bool _connected = false;
  bool _initialized = false;

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
  final _connectionCtrl = StreamController<bool>.broadcast();

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
  Stream<bool> get onConnection => _connectionCtrl.stream;

  bool get isConnected => _connected;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    _connect();
  }

  void _connect() {
    final token = ApiClient.instance.token;
    final userId = ApiClient.instance.userId;
    final baseUrl = ApiClient.baseUrl;

    if (token == null) return;

    _socket = IO.io(baseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'query': {'token': token},
    });

    _socket!.on('connect', (_) {
      _connected = true;
      _connectionCtrl.add(true);
      if (userId != null) {
        _socket!.emit('join:client', {'userId': userId});
      }
    });

    _socket!.on('disconnect', (_) {
      _connected = false;
      _connectionCtrl.add(false);
    });

    _socket!.on('trip:status', (data) {
      if (data is Map) {
        _tripStatusCtrl.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('driver:location', (data) {
      if (data is Map) {
        _driverLocationCtrl.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('new:offer', (data) {
      if (data is Map) {
        _newOfferCtrl.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('offer:accepted', (data) {
      if (data is Map) {
        _offerAcceptedCtrl.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('offer:rejected', (data) {
      if (data is Map) {
        _offerRejectedCtrl.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('message:new', (data) {
      if (data is Map) {
        _messageCtrl.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('notification:new', (data) {
      if (data is Map) {
        _notificationCtrl.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('notification:read', (data) {
      if (data is Map) _notificationCtrl.add(Map<String, dynamic>.from(data));
    });

    _socket!.on('notification:delete', (data) {
      if (data is Map) _notificationCtrl.add(Map<String, dynamic>.from(data));
    });

    _socket!.on('trip:accepted', (data) {
      if (data is Map) {
        _tripAcceptedCtrl.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('trip:completed', (data) {
      if (data is Map) {
        _tripCompletedCtrl.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('trip:cancelled', (data) {
      if (data is Map) {
        _tripCancelledCtrl.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('trip:finalize_request', (data) {
      if (data is Map) {
        _finalizeRequestCtrl.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('trip:finalize_response', (data) {
      if (data is Map) {
        _finalizeResponseCtrl.add(Map<String, dynamic>.from(data));
      }
    });
  }

  void emit(String event, Map<String, dynamic> data) {
    _socket?.emit(event, data);
  }

  void reconnect() {
    _socket?.disconnect();
    _socket?.connect();
  }

  void dispose() {
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
    _connectionCtrl.close();
  }
}
