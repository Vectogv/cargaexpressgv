import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../contracts/socket_events.dart';
import 'api/http_client.dart';
import 'api_client.dart';
import 'error_handler_service.dart';
import 'logger_service.dart';
import 'network_monitor_service.dart';
import 'session_events.dart';

class SocketServiceClient {
  static final SocketServiceClient instance = SocketServiceClient._();
  SocketServiceClient._();

  io.Socket? _socket;
  bool _connected = false;
  bool _initialized = false;

  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 50;
  Timer? _reconnectTimer;
  StreamSubscription<bool>? _networkSub;

  final _tripStatusCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _driverOnWayCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _driverArrivedCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _sosActivatedCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _driverLocationCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _newOfferCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _tripOfferReceivedCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _offerAcceptedCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _offerRejectedCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _offerCancelledCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _offerExpiredCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _tripOfferAcceptedCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _driverStopGpsCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _driverVerificationCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _messageCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _notificationCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _avisosMessageCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _conversationMessageCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _emergencyMessageCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _tripAcceptedCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _tripStartedCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _tripCompletedCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _tripCancelledCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _finalizeRequestCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _finalizeResponseCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _finalizeCancelledCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _closeRejectedCtrl = StreamController<Map<String, dynamic>>.broadcast();
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
  final _moderatorEventCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _disputeUpdatedCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _disputeResolvedCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _tripEtaCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _tripRouteCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _tripDriverNearbyCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _tripGpsFrozenCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _paymentConfirmedCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _paymentRejectedCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _accountPaymentSuspendedCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _ticketMensajeCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _ticketEstadoCtrl = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onTripStatus => _tripStatusCtrl.stream;
  Stream<Map<String, dynamic>> get onDriverOnWay => _driverOnWayCtrl.stream;
  Stream<Map<String, dynamic>> get onDriverArrived => _driverArrivedCtrl.stream;
  Stream<Map<String, dynamic>> get onSosActivated => _sosActivatedCtrl.stream;
  Stream<Map<String, dynamic>> get onDriverLocation => _driverLocationCtrl.stream;
  Stream<Map<String, dynamic>> get onNewOffer => _newOfferCtrl.stream;
  Stream<Map<String, dynamic>> get onTripOfferReceived => _tripOfferReceivedCtrl.stream;
  Stream<Map<String, dynamic>> get onOfferAccepted => _offerAcceptedCtrl.stream;
  Stream<Map<String, dynamic>> get onOfferRejected => _offerRejectedCtrl.stream;

  /// `offer:cancelled {viajeId, ofertaId}`: el conductor reemplazó su oferta
  /// (re-ofertó); el cliente debe quitar la oferta anterior de la lista.
  Stream<Map<String, dynamic>> get onOfferCancelled => _offerCancelledCtrl.stream;

  /// `offer:expired {viajeId, ofertaId}` (sólo conductor): su oferta pendiente
  /// venció sin respuesta del cliente (el backend las expira cada 30 s).
  Stream<Map<String, dynamic>> get onOfferExpired => _offerExpiredCtrl.stream;
  Stream<Map<String, dynamic>> get onTripOfferAccepted => _tripOfferAcceptedCtrl.stream;
  Stream<Map<String, dynamic>> get onDriverStopGps => _driverStopGpsCtrl.stream;
  Stream<Map<String, dynamic>> get onDriverVerification => _driverVerificationCtrl.stream;
  Stream<Map<String, dynamic>> get onMessage => _messageCtrl.stream;
  Stream<Map<String, dynamic>> get onNotification => _notificationCtrl.stream;
  Stream<Map<String, dynamic>> get onAvisosMessage => _avisosMessageCtrl.stream;
  Stream<Map<String, dynamic>> get onConversationMessage => _conversationMessageCtrl.stream;
  Stream<Map<String, dynamic>> get onEmergencyMessage => _emergencyMessageCtrl.stream;
  Stream<Map<String, dynamic>> get onTripAccepted => _tripAcceptedCtrl.stream;
  Stream<Map<String, dynamic>> get onTripStarted => _tripStartedCtrl.stream;
  Stream<Map<String, dynamic>> get onTripCompleted => _tripCompletedCtrl.stream;
  Stream<Map<String, dynamic>> get onTripCancelled => _tripCancelledCtrl.stream;
  Stream<Map<String, dynamic>> get onFinalizeRequest => _finalizeRequestCtrl.stream;
  Stream<Map<String, dynamic>> get onFinalizeResponse => _finalizeResponseCtrl.stream;
  Stream<Map<String, dynamic>> get onFinalizeCancelled => _finalizeCancelledCtrl.stream;
  Stream<Map<String, dynamic>> get onCloseRejected => _closeRejectedCtrl.stream;
  Stream<Map<String, dynamic>> get onTypingStart => _typingStartCtrl.stream;
  Stream<Map<String, dynamic>> get onTypingStop => _typingStopCtrl.stream;
  Stream<Map<String, dynamic>> get onMessageRead => _messageReadCtrl.stream;
  Stream<Map<String, dynamic>> get onAdminStats => _adminStatsCtrl.stream;
  Stream<Map<String, dynamic>> get onAdminDriverLocation => _adminDriverLocationCtrl.stream;
  Stream<Map<String, dynamic>> get onAdminClientLocation => _adminClientLocationCtrl.stream;
  Stream<Map<String, dynamic>> get onAdminDispute => _adminDisputeCtrl.stream;
  Stream<Map<String, dynamic>> get onAdminCancellation => _adminCancellationCtrl.stream;
  Stream<Map<String, dynamic>> get onAdminEmergency => _adminEmergencyCtrl.stream;
  /// Eventos de la sala `moderator:{zona}` (cierres pendientes, viajes y
  /// emergencias de la zona). Cada payload incluye `__event` con el nombre.
  Stream<Map<String, dynamic>> get onModeratorEvent => _moderatorEventCtrl.stream;
  Stream<Map<String, dynamic>> get onDisputeUpdated => _disputeUpdatedCtrl.stream;
  Stream<Map<String, dynamic>> get onDisputeResolved => _disputeResolvedCtrl.stream;
  Stream<Map<String, dynamic>> get onTripEtaUpdate => _tripEtaCtrl.stream;
  Stream<Map<String, dynamic>> get onTripRouteUpdate => _tripRouteCtrl.stream;
  Stream<Map<String, dynamic>> get onTripDriverNearby => _tripDriverNearbyCtrl.stream;
  Stream<Map<String, dynamic>> get onTripGpsFrozen => _tripGpsFrozenCtrl.stream;
  Stream<Map<String, dynamic>> get onPaymentConfirmed => _paymentConfirmedCtrl.stream;
  Stream<Map<String, dynamic>> get onPaymentRejected => _paymentRejectedCtrl.stream;

  /// `account:payment_suspended {estadoCuenta, code, montoDeuda,
  /// deudaFechaLimite, online: false, message}` (conductor): su deuda de
  /// comisión venció; el backend ya lo desconectó.
  Stream<Map<String, dynamic>> get onAccountPaymentSuspended => _accountPaymentSuspendedCtrl.stream;

  /// `ticket:mensaje {ticketId, estado, mensaje: {...}}`: el staff respondió
  /// en un ticket de soporte del usuario.
  Stream<Map<String, dynamic>> get onTicketMensaje => _ticketMensajeCtrl.stream;

  /// `ticket:estado {id, estado, moderador, ...}`: cambio de estado, toma o
  /// asignación de un ticket de soporte del usuario.
  Stream<Map<String, dynamic>> get onTicketEstado => _ticketEstadoCtrl.stream;

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

  void _incrementChatUnreadIfOther(Map data) {
    final senderId = data['senderId']?.toString();
    if (senderId != null && senderId != ApiClient.instance.userId) {
      _chatUnreadCount++;
      _chatUnreadCtrl.add(_chatUnreadCount);
    }
  }

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    _networkSub = NetworkMonitorService.instance.onConnectionChanged.listen((online) {
      if (online && !_connected) {
        LoggerService.instance.info('SocketServiceClient: network restored, reconnecting');
        // Al restaurarse la red se reinicia el contador: no bloquear la
        // reconexión aunque se haya llegado al máximo de intentos previos.
        _reconnectAttempts = 0;
        _scheduleReconnect();
      }
    });

    _connect();
  }

  /// `true` si el error de conexión indica cuenta suspendida
  /// (`message == 'Cuenta suspendida'` o `data.code == 'CUENTA_SUSPENDIDA'`).
  /// `CUENTA_SUSPENDIDA_POR_PAGO` (deuda de comisión) NO lo es: el conductor
  /// sigue con sesión para poder pagar.
  static bool isSuspendedError(dynamic error) {
    try {
      final text = error?.toString() ?? '';
      if (text.contains('CUENTA_SUSPENDIDA_POR_PAGO') ||
          text.toLowerCase().contains('suspendida por pago')) {
        return false;
      }
      if (error is Map) {
        final data = error['data'];
        if (data is Map && data['code']?.toString() == 'CUENTA_SUSPENDIDA') return true;
        if (error['code']?.toString() == 'CUENTA_SUSPENDIDA') return true;
        final msg = error['message']?.toString() ?? '';
        if (msg.toLowerCase().contains('cuenta suspendida')) return true;
      }
      return RegExp(r'CUENTA_SUSPENDIDA(?!_)').hasMatch(text) ||
          text.toLowerCase().contains('cuenta suspendida');
    } catch (_) {
      return false;
    }
  }

  /// Se activa al recibir `Cuenta suspendida`: bloquea reconexiones
  /// automáticas hasta un nuevo login (forceReconnect).
  bool _suspended = false;

  /// Evita ciclos de refresh si el backend sigue rechazando el token.
  bool _authRefreshTried = false;

  static bool _isAuthError(dynamic error) {
    final text = (error is Map ? error['message'] : error)?.toString().toLowerCase() ?? '';
    return text.contains('token de autenticaci') ||
        text.contains('expirado') ||
        text.contains('invalid') ||
        text.contains('inválido');
  }

  Future<void> _refreshAndReconnect() async {
    try {
      final ok = await HttpClient.refreshSessionShared();
      if (ok) {
        _reconnectAttempts = 0;
        _connect();
      } else {
        ErrorHandlerService.instance.emitSessionExpired();
      }
    } catch (_) {
      // Fallo transitorio (red/5xx): reintentar más tarde con backoff.
      _scheduleReconnect();
    }
  }

  void _connect() {
    // Leer SIEMPRE el token actual: tras un refresh el anterior ya no sirve.
    final token = ApiClient.instance.token;
    final baseUrl = ApiClient.baseUrl;

    if (token == null) {
      LoggerService.instance.warning('SocketServiceClient: no token available');
      return;
    }

    try {
      _socket?.dispose();
      _socket = io.io(baseUrl, <String, dynamic>{
        'transports': ['websocket'],
        // El backend lee `auth.token` (preferido) o `query.token` (compat).
        'auth': {'token': token},
        'query': {'token': token},
        'forceNew': true,
        'reconnection': false,
      });

      void safeOn(String event, void Function(dynamic) handler) {
        _socket!.on(event, (data) {
          try {
            handler(data);
          } catch (e, s) {
            LoggerService.instance.error('Socket event "$event" handler error', e, s);
          }
        });
      }

      bool safeAdd<T>(StreamController<T> ctrl, T data) {
        if (!ctrl.isClosed) {
          try {
            ctrl.add(data);
            return true;
          } catch (_) {}
        }
        return false;
      }

      safeOn('connect', (_) {
        _connected = true;
        _reconnectAttempts = 0;
        _authRefreshTried = false;
        safeAdd(_connectionCtrl, true);
        // El backend une el socket a sus rooms (driver/client/admin/user)
        // según el usuario autenticado: no hace falta emitir join:*.
        LoggerService.instance.info('SocketServiceClient connected');
      });

      safeOn('disconnect', (_) {
        _connected = false;
        safeAdd(_connectionCtrl, false);
        LoggerService.instance.warning('SocketServiceClient disconnected');
        _scheduleReconnect();
      });

      safeOn('connect_error', (error) {
        LoggerService.instance.error('SocketServiceClient connect_error', error);
        _connected = false;
        safeAdd(_connectionCtrl, false);
        if (isSuspendedError(error)) {
          // Cuenta suspendida: no reintentar; cerrar sesión globalmente.
          LoggerService.instance.warning('SocketServiceClient: cuenta suspendida, sin reconexión');
          _suspended = true;
          disconnect();
          SessionEvents.instance.emit(const SessionEvent(
            SessionEventType.suspended,
            'Tu cuenta está suspendida. Contacta a soporte.',
          ));
          return;
        }
        if (_isAuthError(error) && !_authRefreshTried) {
          // Token vencido: renovar (refresh compartido con HttpClient) y
          // reconectar con el token nuevo.
          _authRefreshTried = true;
          unawaited(_refreshAndReconnect());
          return;
        }
        _scheduleReconnect();
      });

      safeOn('reconnect_attempt', (_) {
        LoggerService.instance.debug('SocketServiceClient reconnect_attempt');
      });

      // El backend emite `trip:status` y `trip:status_changed` con el mismo
      // payload: escuchar sólo uno para no procesar cada cambio dos veces.
      safeOn(SocketEvents.tripStatusChanged, (data) {
        if (data is Map) safeAdd(_tripStatusCtrl, Map<String, dynamic>.from(data));
      });

      safeOn(SocketEvents.driverOnWay, (data) {
        if (data is Map) safeAdd(_driverOnWayCtrl, Map<String, dynamic>.from(data));
      });

      safeOn(SocketEvents.driverArrived, (data) {
        if (data is Map) safeAdd(_driverArrivedCtrl, Map<String, dynamic>.from(data));
      });

      safeOn(SocketEvents.sosActivated, (data) {
        if (data is Map) safeAdd(_sosActivatedCtrl, Map<String, dynamic>.from(data));
      });

      safeOn('driver:location', (data) {
        if (data is Map) safeAdd(_driverLocationCtrl, Map<String, dynamic>.from(data));
      });

      safeOn('new:offer', (data) {
        if (data is Map) safeAdd(_newOfferCtrl, Map<String, dynamic>.from(data));
      });

      safeOn('trip:offer_received', (data) {
        if (data is Map) safeAdd(_tripOfferReceivedCtrl, Map<String, dynamic>.from(data));
      });

      safeOn('offer:accepted', (data) {
        if (data is Map) safeAdd(_offerAcceptedCtrl, Map<String, dynamic>.from(data));
      });

      safeOn('offer:rejected', (data) {
        if (data is Map) safeAdd(_offerRejectedCtrl, Map<String, dynamic>.from(data));
      });

      safeOn('offer:cancelled', (data) {
        if (data is Map) safeAdd(_offerCancelledCtrl, Map<String, dynamic>.from(data));
      });

      safeOn('offer:expired', (data) {
        if (data is Map) safeAdd(_offerExpiredCtrl, Map<String, dynamic>.from(data));
      });

      safeOn('trip:offer_accepted', (data) {
        if (data is Map) safeAdd(_tripOfferAcceptedCtrl, Map<String, dynamic>.from(data));
      });

      safeOn('driver:stop_gps', (data) {
        if (data is Map) safeAdd(_driverStopGpsCtrl, Map<String, dynamic>.from(data));
      });

      safeOn('driver:approved', (data) {
        if (data is Map) {
          final info = Map<String, dynamic>.from(data);
          info['__event'] = 'driver:approved';
          safeAdd(_driverVerificationCtrl, info);
        }
      });

      safeOn('driver:rejected', (data) {
        if (data is Map) {
          final info = Map<String, dynamic>.from(data);
          info['__event'] = 'driver:rejected';
          safeAdd(_driverVerificationCtrl, info);
        }
      });

      safeOn(SocketEvents.chatMessage, (data) {
        if (data is Map) {
          safeAdd(_messageCtrl, Map<String, dynamic>.from(data));
          _incrementChatUnreadIfOther(data);
        }
      });

      safeOn('avisos:new_message', (data) {
        if (data is Map) safeAdd(_avisosMessageCtrl, Map<String, dynamic>.from(data));
      });

      safeOn('conversation:message', (data) {
        if (data is Map) safeAdd(_conversationMessageCtrl, Map<String, dynamic>.from(data));
      });

      safeOn('emergency:message', (data) {
        if (data is Map) safeAdd(_emergencyMessageCtrl, Map<String, dynamic>.from(data));
      });

      safeOn('notification:new', (data) {
        if (data is Map) safeAdd(_notificationCtrl, {...Map<String, dynamic>.from(data), '__event': 'notification:new'});
      });

      safeOn('notification:read', (data) {
        if (data is Map) safeAdd(_notificationCtrl, {...Map<String, dynamic>.from(data), '__event': 'notification:read'});
      });

      safeOn('notification:delete', (data) {
        if (data is Map) safeAdd(_notificationCtrl, {...Map<String, dynamic>.from(data), '__event': 'notification:delete'});
      });

      safeOn('trip:nearby', (data) {
        if (data is Map) {
          final notification = Map<String, dynamic>.from(data);
          notification['__event'] = 'trip:nearby';
          safeAdd(_notificationCtrl, notification);
        }
      });

      safeOn('trip:accepted', (data) {
        if (data is Map) safeAdd(_tripAcceptedCtrl, Map<String, dynamic>.from(data));
      });

      safeOn('trip:started', (data) {
        if (data is Map) safeAdd(_tripStartedCtrl, Map<String, dynamic>.from(data));
      });

      safeOn('trip:finalized', (data) {
        if (data is Map) safeAdd(_tripCompletedCtrl, Map<String, dynamic>.from(data));
      });

      safeOn('trip:cancelled', (data) {
        if (data is Map) safeAdd(_tripCancelledCtrl, Map<String, dynamic>.from(data));
      });

      safeOn('trip:finalize_request', (data) {
        if (data is Map) safeAdd(_finalizeRequestCtrl, Map<String, dynamic>.from(data));
      });

      safeOn('trip:close_rejected', (data) {
        if (data is Map) safeAdd(_closeRejectedCtrl, Map<String, dynamic>.from(data));
      });

      safeOn('trip:finalize_response', (data) {
        if (data is Map) safeAdd(_finalizeResponseCtrl, Map<String, dynamic>.from(data));
      });

      safeOn('trip:finalize_cancelled', (data) {
        if (data is Map) safeAdd(_finalizeCancelledCtrl, Map<String, dynamic>.from(data));
      });

      safeOn('typing:start', (data) {
        if (data is Map) safeAdd(_typingStartCtrl, Map<String, dynamic>.from(data));
      });

      safeOn('typing:stop', (data) {
        if (data is Map) safeAdd(_typingStopCtrl, Map<String, dynamic>.from(data));
      });

      safeOn('message:read', (data) {
        if (data is Map) safeAdd(_messageReadCtrl, Map<String, dynamic>.from(data));
      });

      safeOn('admin:stats', (data) {
        if (data is Map) safeAdd(_adminStatsCtrl, Map<String, dynamic>.from(data));
      });

      safeOn('admin:driver:location', (data) {
        if (data is Map) safeAdd(_adminDriverLocationCtrl, Map<String, dynamic>.from(data));
      });

      safeOn('admin:client:location', (data) {
        if (data is Map) safeAdd(_adminClientLocationCtrl, Map<String, dynamic>.from(data));
      });

      safeOn('admin:dispute:new', (data) {
        if (data is Map) safeAdd(_adminDisputeCtrl, Map<String, dynamic>.from(data));
      });

      safeOn('admin:cancellation', (data) {
        if (data is Map) safeAdd(_adminCancellationCtrl, Map<String, dynamic>.from(data));
      });

      for (final event in const [
        'moderator:pending_close',
        'moderator:trip:update',
        'moderator:emergency:update',
      ]) {
        safeOn(event, (data) {
          final payload = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
          payload['__event'] = event;
          safeAdd(_moderatorEventCtrl, payload);
        });
      }

      safeOn('admin:emergency', (data) {
        if (data is Map) safeAdd(_adminEmergencyCtrl, Map<String, dynamic>.from(data));
      });

      safeOn('dispute:updated', (data) {
        if (data is Map) safeAdd(_disputeUpdatedCtrl, Map<String, dynamic>.from(data));
      });

      safeOn('dispute:resolved', (data) {
        if (data is Map) safeAdd(_disputeResolvedCtrl, Map<String, dynamic>.from(data));
      });

      safeOn(SocketEvents.tripEtaUpdate, (data) {
        if (data is Map) safeAdd(_tripEtaCtrl, Map<String, dynamic>.from(data));
      });

      safeOn(SocketEvents.tripRouteUpdate, (data) {
        if (data is Map) safeAdd(_tripRouteCtrl, Map<String, dynamic>.from(data));
      });

      safeOn('trip:driver_nearby', (data) {
        if (data is Map) safeAdd(_tripDriverNearbyCtrl, Map<String, dynamic>.from(data));
      });

      safeOn('trip:gps_frozen', (data) {
        if (data is Map) safeAdd(_tripGpsFrozenCtrl, Map<String, dynamic>.from(data));
      });

      safeOn(SocketEvents.paymentConfirmed, (data) {
        if (data is Map) safeAdd(_paymentConfirmedCtrl, Map<String, dynamic>.from(data));
      });

      safeOn(SocketEvents.paymentRejected, (data) {
        if (data is Map) safeAdd(_paymentRejectedCtrl, Map<String, dynamic>.from(data));
      });

      safeOn(SocketEvents.accountPaymentSuspended, (data) {
        if (data is Map) safeAdd(_accountPaymentSuspendedCtrl, Map<String, dynamic>.from(data));
      });

      safeOn(SocketEvents.ticketMensaje, (data) {
        if (data is Map) safeAdd(_ticketMensajeCtrl, Map<String, dynamic>.from(data));
      });

      safeOn(SocketEvents.ticketEstado, (data) {
        if (data is Map) safeAdd(_ticketEstadoCtrl, Map<String, dynamic>.from(data));
      });
    } catch (e) {
      LoggerService.instance.error('SocketServiceClient._connect error', e);
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    if (_suspended) return;
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

  /// Pruebas: entrega [data] a los listeners como si el backend hubiera
  /// emitido [evento] (sólo eventos que usan las pantallas del cliente).
  @visibleForTesting
  void simularEventoParaTest(String evento, Map<String, dynamic> data) {
    final ctrl = <String, StreamController<Map<String, dynamic>>>{
      SocketEvents.tripStatusChanged: _tripStatusCtrl,
      'driver:location': _driverLocationCtrl,
      'new:offer': _newOfferCtrl,
      'offer:accepted': _offerAcceptedCtrl,
      'offer:rejected': _offerRejectedCtrl,
      'offer:expired': _offerExpiredCtrl,
      SocketEvents.paymentConfirmed: _paymentConfirmedCtrl,
      SocketEvents.paymentRejected: _paymentRejectedCtrl,
      SocketEvents.accountPaymentSuspended: _accountPaymentSuspendedCtrl,
      'trip:cancelled': _tripCancelledCtrl,
      'trip:finalize_request': _finalizeRequestCtrl,
      'dispute:updated': _disputeUpdatedCtrl,
      'dispute:resolved': _disputeResolvedCtrl,
      SocketEvents.tripEtaUpdate: _tripEtaCtrl,
      SocketEvents.tripRouteUpdate: _tripRouteCtrl,
      SocketEvents.ticketMensaje: _ticketMensajeCtrl,
      SocketEvents.ticketEstado: _ticketEstadoCtrl,
    }[evento];
    if (ctrl == null) throw ArgumentError('Evento no soportado en pruebas: $evento');
    ctrl.add(data);
  }

  /// Pruebas: simula que el socket se conectó o se cayó (lo que ven las
  /// pantallas por [onConnection]); no toca el socket real ni [isConnected].
  @visibleForTesting
  void simularConexionParaTest(bool conectada) => _connectionCtrl.add(conectada);

  /// Pruebas: observa los eventos que la app intenta emitir.
  @visibleForTesting
  void Function(String event, Map<String, dynamic> data)? onEmitForTest;

  void emit(String event, Map<String, dynamic> data) {
    onEmitForTest?.call(event, data);
    if (_socket != null && _connected) {
      _socket!.emit(event, data);
    } else {
      LoggerService.instance.warning('SocketServiceClient: cannot emit $event, not connected');
    }
  }

  /// Une al cliente con un viaje concreto (ofrecimientos, seguimiento, chat,
  /// finalización). Se re-emite en cada reconexión desde la pantalla activa.
  void joinTrip(String tripId) {
    emit('join:trip', {'tripId': tripId, 'userId': ApiClient.instance.userId});
  }

  void leaveTrip(String tripId) {
    emit('leave:trip', {'tripId': tripId, 'userId': ApiClient.instance.userId});
  }

  /// Reconecta creando un socket nuevo con el token ACTUAL (el handshake del
  /// socket anterior conserva el token viejo).
  void reconnect() {
    if (_suspended) return;
    _reconnectAttempts = 0;
    _reconnectTimer?.cancel();
    _connect();
  }

  /// Reconexión tras login/registro/refresh: limpia el bloqueo por suspensión.
  void forceReconnect() {
    _suspended = false;
    _authRefreshTried = false;
    _reconnectAttempts = 0;
    _reconnectTimer?.cancel();
    _connect();
  }

  /// Desconecta sin cerrar los streams (para logout / cambio de sesión).
  void disconnect() {
    _reconnectTimer?.cancel();
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _connected = false;
    if (!_connectionCtrl.isClosed) {
      try {
        _connectionCtrl.add(false);
      } catch (_) {}
    }
    LoggerService.instance.info('SocketServiceClient disconnected (session change)');
  }

  void dispose() {
    _reconnectTimer?.cancel();
    _networkSub?.cancel();
    _socket?.disconnect();
    _socket?.dispose();
    _tripStatusCtrl.close();
    _driverOnWayCtrl.close();
    _driverArrivedCtrl.close();
    _sosActivatedCtrl.close();
    _driverLocationCtrl.close();
    _newOfferCtrl.close();
    _tripOfferReceivedCtrl.close();
    _offerAcceptedCtrl.close();
    _offerRejectedCtrl.close();
    _offerCancelledCtrl.close();
    _offerExpiredCtrl.close();
    _tripOfferAcceptedCtrl.close();
    _driverStopGpsCtrl.close();
    _driverVerificationCtrl.close();
    _messageCtrl.close();
    _notificationCtrl.close();
    _avisosMessageCtrl.close();
    _conversationMessageCtrl.close();
    _emergencyMessageCtrl.close();
    _tripAcceptedCtrl.close();
    _tripStartedCtrl.close();
    _tripCompletedCtrl.close();
    _tripCancelledCtrl.close();
    _finalizeRequestCtrl.close();
    _finalizeResponseCtrl.close();
    _finalizeCancelledCtrl.close();
    _closeRejectedCtrl.close();
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
    _moderatorEventCtrl.close();
    _disputeUpdatedCtrl.close();
    _disputeResolvedCtrl.close();
    _tripEtaCtrl.close();
    _tripRouteCtrl.close();
    _tripDriverNearbyCtrl.close();
    _tripGpsFrozenCtrl.close();
    _paymentConfirmedCtrl.close();
    _paymentRejectedCtrl.close();
    _accountPaymentSuspendedCtrl.close();
    _ticketMensajeCtrl.close();
    _ticketEstadoCtrl.close();
    _connectionCtrl.close();
  }
}
