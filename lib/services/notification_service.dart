import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'api/http_client.dart';
import 'api/profile_service.dart';
import 'api_client.dart';
import '../contracts/cancelacion.dart';
import '../contracts/socket_events.dart';
import 'socket_service_client.dart';
import 'logger_service.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  /// Notificaciones guardadas en el backend (GET /api/notifications y
  /// `notification:new`).
  final List<Map<String, dynamic>> _remote = [];

  /// Avisos que solo llegan en vivo (socket / push) y no se guardan en el
  /// backend: viaje cancelado, conductor asignado, viaje cercano, push.
  final List<Map<String, dynamic>> _local = [];
  String? _owner;

  /// No leídas de la lista unificada: la campana y la pantalla de
  /// notificaciones usan la MISMA fuente (antes el badge contaba eventos de
  /// socket en memoria y la pantalla listaba solo el backend).
  final ValueNotifier<int> unread = ValueNotifier<int>(0);

  @visibleForTesting
  Future<List<Map<String, dynamic>>> Function() fetchRemote =
      () => ProfileService.getNotifications(limit: 50);
  @visibleForTesting
  Future<void> Function(String id) markRemoteRead = ProfileService.markNotificationRead;
  @visibleForTesting
  bool Function() hasSession = () => ApiClient.instance.token != null;
  @visibleForTesting
  String? Function() currentUser = () => ApiClient.instance.userId;
  @visibleForTesting
  String? Function() currentRol = () => ApiClient.instance.rol;

  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  bool _initialized = false;
  String? _fcmToken;
  final Set<String> _processedTripIds = {};

  // Subscripciones a SocketServiceClient (reemplaza el socket propio)
  StreamSubscription<Map<String, dynamic>>? _tripStatusSub;
  StreamSubscription<Map<String, dynamic>>? _tripAcceptedSub;
  StreamSubscription<Map<String, dynamic>>? _offerAcceptedSub;
  StreamSubscription<Map<String, dynamic>>? _tripCancelledSub;
  StreamSubscription<Map<String, dynamic>>? _notificationSub;

  /// Lista unificada (backend + avisos en vivo), sin duplicados, más
  /// recientes primero. Claves normalizadas: id, titulo, mensaje, tipo,
  /// leido, createdAt.
  List<Map<String, dynamic>> get notifications {
    _checkOwner();
    final all = [..._remote, ..._local];
    all.sort((a, b) => _fecha(b).compareTo(_fecha(a)));
    return List.unmodifiable(all);
  }

  int get unreadCount {
    _checkOwner();
    return _remote.where((n) => n['leido'] != true).length +
        _local.where((n) => n['leido'] != true).length;
  }
  Stream<Map<String, dynamic>> get onNotification => _controller.stream;
  String? get fcmToken => _fcmToken;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    await _initFcm();
    _subscribeToSocketService();
  }

  // En lugar de abrir un socket propio, escuchar del SocketServiceClient existente
  void _subscribeToSocketService() {
    _tripStatusSub = SocketServiceClient.instance.onTripStatus.listen((data) {
      _addNotification({...data, '__event': SocketEvents.tripStatusChanged});
    });

    _tripAcceptedSub = SocketServiceClient.instance.onTripAccepted.listen((data) {
      _addNotification({...data, '__event': 'trip:accepted'});
    });

    _offerAcceptedSub = SocketServiceClient.instance.onOfferAccepted.listen((data) {
      _addNotification({...data, '__event': 'offer:accepted'});
    });

    _tripCancelledSub = SocketServiceClient.instance.onTripCancelled.listen((data) {
      _addNotification({...data, '__event': 'trip:cancelled'});
    });

    _notificationSub = SocketServiceClient.instance.onNotification.listen((data) {
      final event = data['__event'] as String? ?? '';

      if (event == 'trip:nearby') {
        final tripId = (data['tripId'] ?? data['id'])?.toString();
        if (tripId != null && _processedTripIds.contains(tripId)) return;
        if (tripId != null) _processedTripIds.add(tripId);
      }

      _addNotification(data);
    });
  }

  void _addNotification(Map<String, dynamic> data) {
    ingest(data);
    if (!_controller.isClosed) _controller.add(data);
  }

  static DateTime _fecha(Map<String, dynamic> n) =>
      DateTime.tryParse(n['createdAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);

  /// Formato común para la lista (el backend manda titulo/mensaje/leido y
  /// también title/body/read; los push traen title/body).
  static Map<String, dynamic> normalizar(Map<String, dynamic> raw) {
    String? txt(dynamic v) {
      final s = v?.toString().trim();
      return (s == null || s.isEmpty) ? null : s;
    }

    return {
      'id': (raw['_id'] ?? raw['id'])?.toString(),
      'titulo': txt(raw['titulo']) ?? txt(raw['title']),
      'mensaje': txt(raw['mensaje']) ?? txt(raw['body']) ?? txt(raw['message']),
      'tipo': txt(raw['tipo']) ?? txt(raw['type']),
      'leido': raw['leido'] == true || raw['read'] == true,
      'createdAt': txt(raw['createdAt']) ?? DateTime.now().toIso8601String(),
    };
  }

  /// Los avisos en memoria son de la sesión actual: otro usuario no los ve.
  void _checkOwner() {
    final user = currentUser();
    if (user == _owner) return;
    _owner = user;
    _remote.clear();
    _local.clear();
  }

  void _changed() => unread.value = unreadCount;

  /// Clasifica un evento: actualiza la lista unificada si es un aviso visible.
  @visibleForTesting
  void ingest(Map<String, dynamic> data) {
    _checkOwner();
    final event = data['__event'] as String?;
    final id = (data['_id'] ?? data['id'])?.toString();
    switch (event) {
      case 'notification:new':
        final n = normalizar(data);
        _remote.removeWhere((e) => e['id'] == n['id']);
        _remote.add(n);
        break;
      case 'notification:read':
        for (final n in _remote) {
          if (n['id'] == id) n['leido'] = true;
        }
        break;
      case 'notification:delete':
        _remote.removeWhere((n) => n['id'] == id);
        break;
      case 'trip:cancelled':
        final msg = mensajeViajeCancelado(data, miRol: currentRol());
        if (msg == null) return; // lo canceló el propio usuario
        _addLocal('viaje_cancelado', 'Viaje cancelado', msg, id);
        break;
      // El backend emite `offer:accepted` al aceptar una oferta (flujo real);
      // `trip:accepted` sólo sale de una ruta antigua. Un aviso por viaje.
      case 'offer:accepted':
      case 'trip:accepted':
        if (currentRol() != 'cliente') return;
        final tripId = (data['viajeId'] ?? data['tripId'] ?? data['id'])?.toString();
        if (tripId != null &&
            _local.any((n) => n['tipo'] == 'viaje_aceptado' && n['tripId'] == tripId)) {
          return;
        }
        _addLocal('viaje_aceptado', 'Conductor asignado', 'Un conductor aceptó tu viaje.', tripId);
        break;
      case 'trip:nearby':
        if (currentRol() != 'conductor') return;
        final origen = data['origen'];
        final dir = origen is Map ? origen['direccion']?.toString() : null;
        _addLocal('nuevo_viaje', 'Nuevo viaje disponible', dir ?? 'Hay un viaje cerca de ti.', id);
        break;
      default:
        // Push (FCM) con texto; los demás eventos de socket no son avisos.
        if (data['__source'] != 'fcm') return;
        final n = normalizar(data);
        if (n['titulo'] == null && n['mensaje'] == null) return;
        n['id'] = 'local_fcm_${DateTime.now().microsecondsSinceEpoch}';
        _local.add(n);
    }
    _changed();
  }

  void _addLocal(String tipo, String titulo, String mensaje, String? tripId) {
    final ahora = DateTime.now();
    _local.add({
      'id': 'local_${tipo}_${tripId ?? ''}_${ahora.microsecondsSinceEpoch}',
      'titulo': titulo,
      'mensaje': mensaje,
      'tipo': tipo,
      'leido': false,
      'createdAt': ahora.toIso8601String(),
      if (tripId != null) 'tripId': tripId,
    });
  }

  /// Carga las notificaciones del backend. Sin sesión no llama (evita el 401
  /// antes del login o tras cerrar sesión). Un error no rompe la lista:
  /// devuelve false y se conservan las que ya había.
  Future<bool> refresh() async {
    _checkOwner();
    if (!hasSession()) return false;
    try {
      final raw = await fetchRemote();
      _remote
        ..clear()
        ..addAll(raw.map(normalizar).where((n) => n['id'] != null));
      _changed();
      return true;
    } catch (e) {
      LoggerService.instance.warning('NotificationService.refresh error', e);
      return false;
    }
  }

  Future<void> markRead(Map<String, dynamic> n) async {
    final id = n['id']?.toString();
    var remota = false;
    for (final e in _remote) {
      if (e['id'] == id && e['leido'] != true) {
        e['leido'] = true;
        remota = true;
      }
    }
    for (final e in _local) {
      if (e['id'] == id) e['leido'] = true;
    }
    _changed();
    if (remota && id != null && hasSession()) {
      try {
        await markRemoteRead(id);
      } catch (e) {
        LoggerService.instance.warning('NotificationService.markRead error', e);
      }
    }
  }

  Future<void> _initFcm() async {
    if (kIsWeb) return;
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      _fcmToken = await messaging.getToken();
      if (_fcmToken != null) await _registerToken(_fcmToken!);

      messaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        _registerToken(newToken);
      });

      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) _handleNotificationTap(initialMessage);
    } catch (e) {
      LoggerService.instance.error('NotificationService._initFcm error', e);
    }
  }

  Future<void> _registerToken(String token) async {
    try {
      if (ApiClient.instance.token == null) return;
      // HttpClient: renueva el token ante 401 y maneja suspensión/timeouts.
      await HttpClient.put('/api/users/fcm-token', body: {'fcmToken': token}, auth: true);
    } catch (e) {
      LoggerService.instance.error('NotificationService._registerToken error', e);
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final data = message.data;
    if (data['type'] == 'new_trip' || data['event'] == 'trip:nearby') {
      final tripId = data['tripId'] ?? data['id'];
      if (tripId != null && _processedTripIds.contains(tripId.toString())) return;
      if (tripId != null) _processedTripIds.add(tripId.toString());
    }
    final entry = <String, dynamic>{
      if (message.notification?.title != null) 'title': message.notification!.title,
      if (message.notification?.body != null) 'body': message.notification!.body,
      if (data.isNotEmpty) ...data,
      '__source': 'fcm',
    };
    _addNotification(entry);
  }

  void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    final entry = <String, dynamic>{
      if (message.notification?.title != null) 'title': message.notification!.title,
      if (message.notification?.body != null) 'body': message.notification!.body,
      if (data.isNotEmpty) ...data,
      '__source': 'fcm',
      '__tap': true,
    };
    if (data['type'] == 'new_trip' || data['event'] == 'trip:nearby') {
      entry['__navigate'] = 'offers';
    }
    _addNotification(entry);
  }

  void clearDuplicateTracking() => _processedTripIds.clear();

  Future<void> markAllRead() async {
    final pendientes = _remote
        .where((n) => n['leido'] != true)
        .map((n) => n['id'] as String)
        .toList();
    for (final n in [..._remote, ..._local]) {
      n['leido'] = true;
    }
    _changed();
    if (!hasSession()) return;
    for (final id in pendientes) {
      try {
        await markRemoteRead(id);
      } catch (e) {
        LoggerService.instance.warning('NotificationService.markAllRead error', e);
      }
    }
  }

  @visibleForTesting
  void resetForTest() {
    _remote.clear();
    _local.clear();
    _owner = currentUser();
    _changed();
  }

  void dispose() {
    _tripStatusSub?.cancel();
    _tripAcceptedSub?.cancel();
    _offerAcceptedSub?.cancel();
    _tripCancelledSub?.cancel();
    _notificationSub?.cancel();
    _controller.close();
  }
}
