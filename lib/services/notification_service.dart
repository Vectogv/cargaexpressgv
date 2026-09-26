import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
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

  /// Qué hacer al tocar un push de ticket de soporte (`tipo` =
  /// `ticket_mensaje` / `ticket_estado`): abrir el detalle del ticket. Lo
  /// conecta `main.dart` (los servicios no importan pantallas).
  void Function(String ticketId)? abrirTicket;

  /// Tipos de push/notificación que llevan al detalle de un ticket.
  static bool esTipoTicket(String? tipo) => tipo == 'ticket_mensaje' || tipo == 'ticket_estado';

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

  /// Pruebas: entrega [data] (con `__event`) a las pantallas suscritas a
  /// [onNotification] como si hubiera llegado por el socket.
  @visibleForTesting
  void simularEventoParaTest(String evento, Map<String, dynamic> data) =>
      _addNotification({...data, '__event': evento});

  static DateTime _fecha(Map<String, dynamic> n) =>
      DateTime.tryParse(n['createdAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);

  /// Formato común para la lista (el backend manda titulo/mensaje/leido y
  /// también title/body/read; los push traen title/body).
  static Map<String, dynamic> normalizar(Map<String, dynamic> raw) {
    String? txt(dynamic v) {
      final s = v?.toString().trim();
      return (s == null || s.isEmpty) ? null : s;
    }

    final ticketId = ticketIdDe(raw);
    return {
      'id': (raw['_id'] ?? raw['id'])?.toString(),
      'titulo': txt(raw['titulo']) ?? txt(raw['title']),
      'mensaje': txt(raw['mensaje']) ?? txt(raw['body']) ?? txt(raw['message']),
      'tipo': txt(raw['tipo']) ?? txt(raw['type']),
      'leido': raw['leido'] == true || raw['read'] == true,
      'createdAt': txt(raw['createdAt']) ?? DateTime.now().toIso8601String(),
      if (ticketId != null) 'ticketId': ticketId,
    };
  }

  /// Id del ticket de una notificación/push de soporte: en la raíz
  /// (`data` del push FCM) o dentro de `data`/`datos` (notificación guardada).
  static String? ticketIdDe(Map<String, dynamic> raw) {
    String? txt(dynamic v) {
      final s = v?.toString().trim();
      return (s == null || s.isEmpty) ? null : s;
    }

    final directo = txt(raw['ticketId']);
    if (directo != null) return directo;
    for (final clave in const ['data', 'datos', 'metadata']) {
      final anidado = raw[clave];
      if (anidado is Map) {
        final id = txt(anidado['ticketId']);
        if (id != null) return id;
      }
    }
    return null;
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
        if (esCanceladoPorSistema(
          canceladoPor: data['canceladoPor']?.toString(),
          motivo: data['motivo']?.toString(),
        )) {
          _addLocal('busqueda_sin_conductor', avisoSinConductor().titulo, msg, id);
        } else {
          _addLocal('viaje_cancelado', 'Viaje cancelado', msg, id);
        }
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
      // El permiso se pide aparte (pedirPermisoNotificaciones, con pantalla)
      // y un fallo del token no debe cortar el resto de la configuración.
      try {
        _fcmToken = await messaging.getToken();
        if (_fcmToken != null) await _registerToken(_fcmToken!);
      } catch (e) {
        LoggerService.instance.error('NotificationService.getToken (inicio) error', e);
      }

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

  @visibleForTesting
  set fcmTokenParaTest(String? token) => _fcmToken = token;

  /// Tras login o registro: [init] suele haber corrido al abrir la app sin
  /// sesión, así que el token FCM aún no se registró en el backend.
  Future<void> registrarTokenSesion() async {
    unawaited(pedirPermisoNotificaciones());
    var token = _fcmToken;
    Object? ultimoError;
    // SERVICE_NOT_AVAILABLE suele ser transitorio y Firebase no reintenta.
    for (var intento = 0; (token == null || token.isEmpty) && !kIsWeb && intento < 3; intento++) {
      if (intento > 0) await Future<void>.delayed(const Duration(seconds: 5));
      try {
        token = _fcmToken = await obtenerTokenFcm();
        ultimoError = null;
        break; // sin error: no hay nada que reintentar
      } catch (e) {
        ultimoError = e;
        LoggerService.instance.error('NotificationService.getToken error', e);
      }
    }
    if (token == null || token.isEmpty) {
      if (ultimoError != null) await _reportarFalloToken(ultimoError);
      return;
    }
    await _registerToken(token);
  }

  /// Sin token el backend no puede enviar push; se le informa el motivo
  /// para diagnosticarlo desde sus logs (el dispositivo no está a mano).
  Future<void> _reportarFalloToken(Object error) async {
    try {
      if (!hasSession()) return;
      final inicio = errorInicioFirebase;
      // El error del arranque primero: el backend guarda sólo 300 caracteres.
      final motivo = '${inicio != null ? 'init: $inicio | ' : ''}$error';
      await HttpClient.put('/api/users/fcm-token', body: {
        'error': motivo.length > 300 ? motivo.substring(0, 300) : motivo,
      }, auth: true);
    } catch (_) {}
  }

  bool _permisoPedido = false;

  /// Error de Firebase.initializeApp en main.dart (null si inició bien).
  String? errorInicioFirebase;

  /// Reemplazable en pruebas (sin Firebase).
  @visibleForTesting
  Future<String?> Function() obtenerTokenFcm = () async {
    // Si el arranque no dejó Firebase listo (visto: "[core/no-app]" en un
    // Honor 200), se inicializa aquí antes de pedir el token.
    if (Firebase.apps.isEmpty) await Firebase.initializeApp();
    return FirebaseMessaging.instance.getToken();
  };

  /// Reemplazable en pruebas (sin plataforma ni temporizadores).
  @visibleForTesting
  Future<void> Function() pedirPermisoNotificaciones = () => NotificationService.instance._pedirPermisoConPantalla();

  /// Android 13+ (POST_NOTIFICATIONS): las notificaciones vienen apagadas
  /// hasta que la app pide permiso. [init] lo pedía durante el arranque, sin
  /// pantalla, y Android no mostraba el diálogo (visto en un Honor 200): el
  /// push llegaba pero no se mostraba. Se vuelve a pedir ya con la sesión y
  /// la pantalla de inicio visibles, con una pausa para no coincidir con el
  /// diálogo de ubicación.
  Future<void> _pedirPermisoConPantalla() async {
    if (kIsWeb || _permisoPedido) return;
    _permisoPedido = true;
    try {
      await Future<void>.delayed(const Duration(seconds: 2));
      await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
    } catch (e) {
      LoggerService.instance.error('NotificationService.requestPermission error', e);
    }
  }

  Future<void> _registerToken(String token) async {
    try {
      if (!hasSession()) return;
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
    manejarToqueDePush(
      message.data,
      titulo: message.notification?.title,
      cuerpo: message.notification?.body,
    );
  }

  /// El usuario tocó un push (app en segundo plano o cerrada). [data] son los
  /// datos del FCM (todos strings). Un push de ticket de soporte
  /// (`tipo: ticket_mensaje | ticket_estado`, `ticketId`) abre el detalle
  /// del ticket con [abrirTicket].
  @visibleForTesting
  void manejarToqueDePush(Map<String, dynamic> data, {String? titulo, String? cuerpo}) {
    final entry = <String, dynamic>{
      if (titulo != null) 'title': titulo,
      if (cuerpo != null) 'body': cuerpo,
      if (data.isNotEmpty) ...data,
      '__source': 'fcm',
      '__tap': true,
    };
    if (data['type'] == 'new_trip' || data['event'] == 'trip:nearby') {
      entry['__navigate'] = 'offers';
    }
    final ticketId = ticketIdDe(data);
    if (esTipoTicket(data['tipo']?.toString()) && ticketId != null) {
      entry['__navigate'] = 'ticket';
      final abrir = abrirTicket;
      if (abrir != null && hasSession()) {
        try {
          abrir(ticketId);
        } catch (e) {
          LoggerService.instance.error('NotificationService.abrirTicket error', e);
        }
      }
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
