import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../contracts/solicitud.dart' show idDeViaje;
import '../../contracts/trip_status.dart';
import '../../contracts/socket_events.dart';
import '../../widgets/carga_express_bottom_nav.dart';
import '../../widgets/solicitud_viaje_sheet.dart';
import '../../models/trip.dart';
import '../../services/api_client.dart';
import '../../services/api/http_client.dart' show ApiException;
import '../../services/cache_service.dart';
import '../../services/notification_service.dart';
import '../../services/socket_service_client.dart';
import '../../services/driver_location_service.dart';
import '../../services/solicitudes_disponibles_service.dart';
import '../../services/api/driver_service.dart';
import '../../services/map_config.dart';
import '../user/auth_screen.dart';
import 'trip_in_progress_screen.dart';
import 'offers_screen.dart';
import 'earnings_screen.dart';
import 'trip_chat_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'documents_screen.dart';
import 'trip_history_screen.dart';
import 'support_screen.dart';
import 'settings_screen.dart';
import 'solicitudes_disponibles_screen.dart';
import 'solicitudes_disponibles_section.dart';
import 'aviso_cuenta_pago.dart';
import '../shared/tickets/nuevo_ticket_screen.dart';
import '../shared/ui_compartida.dart' show FondoDegradado, TarjetaBlanca;
import '../shared/cuenta_no_activa_dialog.dart' show CuentaNoActivaDialog;
import '../../core/formato_dinero.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _bottomIndex = 0;
  bool _online = true;
  bool _statusLoading = false;
  Map<String, dynamic>? _activeTrip;
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _stats;
  Timer? _uiTimer;

  StreamSubscription<Map<String, dynamic>>? _socketSub;
  StreamSubscription<List<SolicitudDisponible>>? _solicitudesSub;
  StreamSubscription<Map<String, dynamic>>? _pagoSuspendidoSub;
  StreamSubscription<Map<String, dynamic>>? _pagoConfirmadoSub;
  StreamSubscription<Map<String, dynamic>>? _pagoRechazadoSub;

  /// GET /api/payment/debt: deuda de comisión y `estadoCuenta`.
  Map<String, dynamic>? _deuda;
  EstadoPagoConductor get _estadoPago => estadoPagoConductor(_deuda);

  /// Viaje que ocupa al conductor. `pendiente_confirmacion` sólo espera la
  /// confirmación del cliente (el backend no lo cuenta como ocupado): puede
  /// conectarse y tomar otro viaje mientras tanto.
  bool get _viajeOcupa =>
      _activeTrip != null && _activeTrip!['estado'] != TripStatus.pendienteConfirmacion;

  /// Solicitudes por las que ya salió el aviso emergente (visto o ignorado):
  /// no se repite, pero la solicitud sigue en "Solicitudes disponibles".
  final Set<String> _avisadasTripIds = {};
  final Set<String> _activeBannerIds = {};

  /// Cuántas solicitudes mostrar en el inicio; el resto en la pantalla propia.
  static const int _maxSolicitudesInicio = 5;

  static const Color _primaryBlue = Color(0xFF1A3C6E);
  static const Color _accentBlue = Color(0xFF2563EB);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _white = Colors.white;
  static const Color _accentGreen = Color(0xFF4CAF50);
  static const Color _textDark = Color(0xFF1A1A2E);
  static const Color _textGrey = Color(0xFF757575);
  static const Color _bgLight = Color(0xFFF5F7FA);

  @override
  void initState() {
    super.initState();
    _fetchData();

    _socketSub = NotificationService.instance.onNotification.listen((event) async {
      final tipo = event['__event'] as String?;
      if (tipo == 'trip:nearby') {
        // Entra a la lista de inmediato (el sondeo completa los datos) y,
        // si el conductor está libre, sale el aviso emergente.
        SolicitudesDisponiblesService.instance.ingresarAvisoSocket(event);
        final tripId = idDeViaje(event);
        if (!_viajeOcupa && tripId != null && !_avisadasTripIds.contains(tripId)) {
          _showNewTripBanner(event);
        }
      } else if (tipo == 'trip:accepted') {
        SolicitudesDisponiblesService.instance.quitar(event['tripId'] ?? event['id']);
        await _fetchActiveTrip();
        if (_activeTrip != null) {
          CacheService.instance.cacheActiveTrip(_activeTrip!);
          _redirectToActiveTrip();
        }
      } else if (tipo == SocketEvents.tripStatusChanged) {
        final estado = event['estado'] as String?;
        if (estado == TripStatus.esperaConfirmacion || estado == TripStatus.finalizado || estado == TripStatus.cancelado) {
          if (mounted) setState(() => _activeTrip = null);
        } else {
          _fetchActiveTrip();
        }
      }
    });

    // Sondeo de respaldo (sin socket): aviso emergente sólo por la primera
    // solicitud nueva sin oferta propia; todas quedan en la lista.
    _solicitudesSub = SolicitudesDisponiblesService.instance.cambios.listen((lista) {
      if (_viajeOcupa) return;
      // Con oferta propia el conductor ya la conoce: sin aviso (tampoco si
      // luego el cliente la rechaza; la tarjeta lo indica).
      _avisadasTripIds.addAll(lista.where((s) => s.tieneOferta).map((s) => s.id));
      final nuevas = lista.where((s) => !_avisadasTripIds.contains(s.id)).toList();
      if (nuevas.isEmpty) return;
      _avisadasTripIds.addAll(nuevas.map((s) => s.id));
      _showNewTripBanner(nuevas.first.viaje);
    });

    // Suspensión por deuda de comisión: el backend ya lo desconectó.
    _pagoSuspendidoSub = SocketServiceClient.instance.onAccountPaymentSuspended.listen((data) {
      _aplicarBloqueoPago(data);
      _avisarBloqueoPago(data['message']?.toString() ??
          'Tu cuenta fue suspendida por pago pendiente. Sube el comprobante para reactivarla.');
    });
    _pagoConfirmadoSub = SocketServiceClient.instance.onPaymentConfirmed.listen((data) {
      if (!mounted) return;
      // Puede quedar saldo (viajes terminados durante la revisión): la cuenta
      // queda activa y el aviso de deuda sigue con lo que falta.
      setState(() => _deuda = deudaTrasPagoConfirmado(_deuda, data));
      unawaited(_cargarDeuda());
      _snack(mensajePagoConfirmado(data));
    });
    _pagoRechazadoSub = SocketServiceClient.instance.onPaymentRejected.listen((data) {
      if (!mounted) return;
      // El backend devuelve la cuenta a suspension_por_pago.
      setState(() => _deuda = {...?_deuda, 'estadoCuenta': 'suspension_por_pago'});
      unawaited(_cargarDeuda());
      _avisarBloqueoPago(data['message']?.toString() ??
          'Tu comprobante no fue válido. Sube un nuevo comprobante de pago.');
    });
  }

  @override
  void dispose() {
    _socketSub?.cancel();
    _solicitudesSub?.cancel();
    _pagoSuspendidoSub?.cancel();
    _pagoConfirmadoSub?.cancel();
    _pagoRechazadoSub?.cancel();
    _uiTimer?.cancel();
    // El inicio es la raíz del conductor: sin él no hay quién muestre la lista.
    SolicitudesDisponiblesService.instance.detener();
    super.dispose();
  }

  /// Conectado, libre y sin bloqueo de pago: la lista de solicitudes se
  /// mantiene viva aunque el GPS aún no responda (el backend usa la última
  /// ubicación guardada). En cualquier otro caso se detiene.
  void _actualizarSolicitudes() {
    if (_online && !_viajeOcupa && !_estadoPago.bloqueaConexion) {
      SolicitudesDisponiblesService.instance.iniciar();
    } else {
      SolicitudesDisponiblesService.instance.detener();
    }
  }

  Future<void> _fetchData() async {
    await _fetchProfileFirst();
    final cachedTrip = CacheService.instance.getCachedActiveTrip();
    if (cachedTrip != null) {
      final estado = cachedTrip['estado'] as String?;
      // `pendiente_confirmacion` en caché no basta: el backend puede tener ya
      // un viaje activo nuevo (tiene prioridad) o haberlo cerrado.
      if (estado == TripStatus.aceptado || estado == TripStatus.enCamino || estado == TripStatus.llegada || estado == TripStatus.enCurso || estado == TripStatus.entregado || estado == TripStatus.esperaConfirmacion) {
        if (mounted) setState(() => _activeTrip = cachedTrip);
        _redirectToActiveTrip();
        return;
      }
    }
    await _fetchActiveTrip();
    if (_activeTrip != null) {
      CacheService.instance.cacheActiveTrip(_activeTrip!);
      _redirectToActiveTrip();
    }
    // Esperando la confirmación del cliente no impide conectarse.
    if (_viajeOcupa) return;
    if (_online) {
      final estado = _verificacionEstado;
      if (estado == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudo verificar tu estado. Revisa tu conexión e intenta de nuevo.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 6),
            ),
          );
          setState(() => _online = false);
        }
        return;
      }
      if (estado != 'aprobado') {
        // Sin aprobación el backend no lo deja conectarse: el interruptor no
        // debe quedar en "Conectado" (valor inicial) sin haberlo pedido.
        if (mounted) setState(() => _online = false);
        return;
      }
      if (!mounted) return;
      if (_estadoPago.bloqueaConexion) {
        // Suspendido por pago o comprobante en revisión: el backend no lo deja
        // conectarse (el aviso del inicio explica qué hacer).
        DriverLocationService.instance.stop();
        setState(() => _online = false);
        return;
      }
      final messenger = ScaffoldMessenger.of(context);
      try {
        await ApiClient.instance.setDriverStatus(true);
      } catch (e) {
        // El backend rechaza (403) si el conductor no está verificado o está
        // suspendido: no fingir que está en línea.
        DriverLocationService.instance.stop();
        if (mounted) setState(() => _online = false);
        if (e is ApiException && e.code == codigoSuspensionPago) {
          _aplicarBloqueoPago(e.data);
          _avisarBloqueoPago(e.message);
          return;
        }
        messenger.showSnackBar(SnackBar(
          content: Text(_errorMessage(e)),
          backgroundColor: Colors.orange,
        ));
        return;
      }
      _actualizarSolicitudes();
      if (!await DriverLocationService.instance.start()) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Permiso de ubicación denegado. Actívalo en Ajustes.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _redirectToActiveTrip() {
    if (!mounted) return;
    // Evitar apilar varias TripInProgressScreen: si ya hay otra pantalla
    // encima (p.ej. el propio viaje abierto), no volver a hacer push.
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final current = ModalRoute.of(context);
      if (current != null && !current.isCurrent) return;
      _abrirViaje(_activeTrip);
    });
  }

  /// Abre la vista del viaje. Al volver de un viaje que sólo espera la
  /// confirmación del cliente, reanuda la búsqueda de viajes si está en
  /// línea (la vista del viaje pausa el GPS del inicio).
  Future<void> _abrirViaje(Map<String, dynamic>? viaje) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => TripInProgressScreen(trip: viaje != null ? Trip.fromJson(viaje) : null)));
    if (!mounted) return;
    await _fetchActiveTrip();
    if (!mounted) return;
    _actualizarSolicitudes();
    if (_online && !_viajeOcupa && !_estadoPago.bloqueaConexion) {
      unawaited(DriverLocationService.instance.start());
    }
  }

  Future<void> _fetchActiveTrip() async {
    try {
      final trip = await ApiClient.instance.getActiveTrip();
      if (trip != null) {
        final estado = trip['estado'] as String?;
        final activeStates = [TripStatus.aceptado, TripStatus.enCamino, TripStatus.llegada, TripStatus.enCurso, TripStatus.entregado, TripStatus.esperaConfirmacion, TripStatus.pendienteConfirmacion];
        if (activeStates.contains(estado)) {
          CacheService.instance.cacheActiveTrip(trip);
          if (mounted) setState(() => _activeTrip = trip);
          return;
        }
      }
      CacheService.instance.clearActiveTrip();
    } catch (_) {
      CacheService.instance.clearActiveTrip();
    }
    if (mounted) {
      setState(() => _activeTrip = null);
    }
  }

  Future<void> _fetchProfileFirst() async {
    try {
      final profile = await ApiClient.instance.getProfile();
      if (mounted) setState(() => _profile = profile);
    } catch (e) {
      debugPrint('Error cargando perfil: $e');
    }
    await _cargarDeuda();
    unawaited(_loadStats());
    // Refresca el resumen cada minuto. La posición del mapa la refresca el
    // propio _DriverMiniMap (antes un setState() global cada 20 s reconstruía
    // toda la pantalla y recreaba el FlutterMap por su ValueKey).
    _uiTimer ??= Timer.periodic(const Duration(seconds: 60), (_) {
      if (!mounted) return;
      unawaited(_loadStats());
    });
  }

  /// GET /api/payment/debt (permitido aunque la cuenta esté suspendida por
  /// pago). Si falla se conserva lo último conocido.
  Future<void> _cargarDeuda() async {
    try {
      final deuda = await ApiClient.instance.getDebt();
      if (mounted) setState(() => _deuda = deuda);
    } catch (e) {
      debugPrint('Error cargando deuda: $e');
    }
  }

  /// Cuenta suspendida por pago (403 CUENTA_SUSPENDIDA_POR_PAGO o socket
  /// `account:payment_suspended`): queda desconectado sin cerrar sesión.
  void _aplicarBloqueoPago(Map<String, dynamic>? data) {
    DriverLocationService.instance.stop();
    if (!mounted) return;
    setState(() {
      _online = false;
      _deuda = {
        ...?_deuda,
        'estadoCuenta': data?['estadoCuenta'] ?? 'suspension_por_pago',
        if (data?['montoDeuda'] != null) 'montoDeuda': data!['montoDeuda'],
        if (data?['deudaFechaLimite'] != null) 'deudaFechaLimite': data!['deudaFechaLimite'],
      };
    });
    unawaited(_cargarDeuda());
  }

  /// Aplica un cambio llegado por socket fuera del build en curso y
  /// garantiza que haya un frame (ver rastreo_screen._trasFrame).
  void _trasFrame(VoidCallback fn) {
    WidgetsBinding.instance.addPostFrameCallback((_) => fn());
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  bool _dialogoPagoAbierto = false;

  /// Bloqueo por pago (suspendida o comprobante en revisión): el mismo
  /// diálogo que ve el cliente, con el monto y acceso a Pagos (Ganancias).
  void _avisarBloqueoPago(String mensaje) {
    if (!mounted || _dialogoPagoAbierto) return;
    _dialogoPagoAbierto = true;
    _trasFrame(() {
      if (!mounted) {
        _dialogoPagoAbierto = false;
        return;
      }
      showDialog<void>(
        context: context,
        builder: (_) => CuentaNoActivaDialog(
          mensaje: mensaje,
          estadoCuenta: _deuda?['estadoCuenta']?.toString(),
          montoDeuda: _deuda?['montoDeuda'],
          onIrAPagos: _abrirPagos,
        ),
      ).whenComplete(() => _dialogoPagoAbierto = false);
    });
  }

  void _snack(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  /// Ganancias: muestra la deuda y permite subir el comprobante de pago.
  Future<void> _abrirPagos() async {
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const EarningsScreen()));
    if (mounted) unawaited(_cargarDeuda());
  }

  Future<void> _loadStats() async {
    try {
      final stats = await DriverService.getTodayStats();
      if (mounted) setState(() => _stats = stats);
    } catch (_) {}
  }

  Future<void> _toggleStatus() async {
    if (mounted) setState(() => _statusLoading = true);
    try {
      if (!_online) {
        // Verificar estado primero
        final estado = _verificacionEstado;
        if (estado == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cargando tu perfil... intenta en un momento'), backgroundColor: Colors.orange),
          );
          }
          return;
        }
        if (estado != 'aprobado') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: const Text('Tu cuenta no está aprobada para recibir viajes'),
              backgroundColor: Colors.orange,
              action: SnackBarAction(label: 'Documentos', textColor: Colors.white, onPressed: () => _navigate(10)),
            ));
          }
          return;
        }
        if (_estadoPago.bloqueaConexion) {
          _avisarBloqueoPago(_estadoPago == EstadoPagoConductor.enRevision
              ? 'Tu comprobante de pago está en revisión. Podrás conectarte cuando sea aprobado.'
              : 'Tu cuenta está suspendida por pago pendiente. Sube el comprobante para conectarte.');
          return;
        }
        // Intentar GPS primero
        final gpsOk = await DriverLocationService.instance.start();
        if (!gpsOk) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permiso de ubicación denegado. Actívalo en Ajustes.'), backgroundColor: Colors.red),
          );
          }
          return; // NO marcar online si GPS falló
        }
        try {
          await ApiClient.instance.setDriverStatus(true);
        } catch (_) {
          // Revertir: el backend no nos marcó en línea (p.ej. 403 no verificado).
          DriverLocationService.instance.stop();
          if (mounted) setState(() => _online = false);
          rethrow;
        }
        if (mounted) setState(() => _online = true); // Solo aquí
        _actualizarSolicitudes();
      } else {
        // Primero el backend; si falla seguimos en línea (estado coherente).
        await ApiClient.instance.setDriverStatus(false);
        DriverLocationService.instance.stop();
        if (mounted) setState(() => _online = false);
      }
    } catch (e) {
      if (e is ApiException && e.code == codigoSuspensionPago) {
        _aplicarBloqueoPago(e.data);
        _avisarBloqueoPago(e.message);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorMessage(e)), backgroundColor: Colors.orange),
        );
      }
    } finally {
      if (mounted) setState(() => _statusLoading = false);
    }
  }

  String _errorMessage(Object e) {
    if (e is ApiException) return e.message;
    return 'Error: ${e.toString().replaceFirst("Exception: ", "")}';
  }

  void _showNewTripBanner(Map<String, dynamic> event) {
    if (!mounted) return;
    // Payload mínimo por socket: {tripId, origen: string, precioEstimado, type}
    // Payload completo (polling cercanos): {id/_id, origen: {direccion,..}, precioEstimado, ...}
    final tripId = (event['tripId'] ?? event['id'] ?? event['_id'])?.toString();
    if (tripId == null || tripId.isEmpty) return;
    if (_activeBannerIds.contains(tripId)) return; // deduplicar
    _activeBannerIds.add(tripId);
    _avisadasTripIds.add(tripId);

    // "Ignorar" sólo cierra el aviso: la solicitud sigue en la lista mientras
    // el backend la tenga buscando conductor.
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SolicitudViajeSheet(
        tripId: tripId,
        resumen: event,
        conductorLat: DriverLocationService.instance.lastLat,
        conductorLng: DriverLocationService.instance.lastLng,
        onVer: () {
          if (mounted) abrirDetalleSolicitud(context, tripId);
        },
      ),
    ).whenComplete(() => _activeBannerIds.remove(tripId));
  }

  String? get _verificacionEstado {
    final conductor = _profile?['conductor'] as Map<String, dynamic>?;
    return conductor?['estadoVerificacion'] as String?;
  }

  String _statusLabel() {
    final estado = _verificacionEstado;
    if (estado == 'rechazado' || estado == 'pendiente') return 'Pendiente de verificaci\u00f3n';
    if (!_online) return 'Fuera de l\u00ednea';
    return 'En l\u00ednea';
  }

  Color _statusColor() {
    final estado = _verificacionEstado;
    if (estado == 'rechazado' || estado == 'pendiente') return Colors.orange;
    if (!_online) return Colors.grey;
    return _accentGreen;
  }

  void _navigate(int index) {
    if (index == 5) {
      SocketServiceClient.instance.resetChatUnread();
    }
    final routes = <int, Widget>{
      1: TripInProgressScreen(trip: _activeTrip != null ? Trip.fromJson(_activeTrip!) : null),
      2: const OffersScreen(),
      4: const EarningsScreen(),
      5: TripChatScreen(trip: _activeTrip),
      6: const NotificationsScreen(),
      9: const ProfileScreen(),
      10: const DocumentsScreen(),
      11: const TripHistoryScreen(),
      12: const SupportScreen(),
      13: const SettingsScreen(),
      14: const SolicitudesDisponiblesScreen(),
    };
    final route = routes[index];
    if (route != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => route));
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Próximamente disponible'), duration: Duration(seconds: 2)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _bgLight,
      drawer: _buildDrawer(),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _buildHomeContent(),
          ),
        ],
      ),
      bottomNavigationBar: CargaExpressBottomNav(
        currentIndex: _bottomIndex,
        items: [
          (icon: Icons.home_rounded, label: 'Inicio', onTap: () {
            setState(() => _bottomIndex = 0);
          }),
          (icon: Icons.receipt_long_rounded, label: 'Viajes', onTap: () {
            _navigate(11);
          }),
          (icon: Icons.bar_chart_rounded, label: 'Ingresos', onTap: () {
            _navigate(4);
          }),
          (icon: Icons.person_rounded, label: 'Perfil', onTap: () {
            _navigate(9);
          }),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    DriverLocationService.instance.stop();
    await ApiClient.instance.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (_) => false,
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1A3C6E), Color(0xFF1565C0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: _white.withValues(alpha: 0.2),
                  child: Text(
                    _initials(ApiClient.instance.nombreCompleto),
                    style: TextStyle(color: _white, fontWeight: FontWeight.w700, fontSize: 18),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ApiClient.instance.nombreCompleto,
                        style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () {
                          final estado = _verificacionEstado;
                          if (estado == 'rechazado' || estado == 'pendiente') {
                            Navigator.pop(context);
                            _navigate(10);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: _statusColor(),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _statusLabel(),
                            style: const TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(Icons.inbox_outlined, 'Solicitudes disponibles', 14),
                _buildDrawerItem(Icons.local_offer_outlined, 'Mis ofertas', 2),
                _buildDrawerItem(Icons.person_outline, 'Perfil', 9),
                _buildDrawerItem(Icons.description_outlined, 'Documentaci\u00f3n', 10),
                _buildDrawerItem(Icons.route_outlined, 'Historial de viajes', 11),
                _buildDrawerItem(Icons.chat_bubble_outline, 'Mensajes', 5),
                _buildDrawerItem(Icons.notifications_none, 'Notificaciones', 6),
                _buildDrawerItem(Icons.settings_outlined, 'Ajustes', 13),
                _buildDrawerItem(Icons.headset_mic_outlined, 'Soporte', 12),
                const Divider(),
                _buildDrawerItem(Icons.logout, 'Cerrar sesi\u00f3n', -1, isDestructive: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String label, int index, {bool isDestructive = false}) {
    return ListTile(
      leading: Icon(icon, color: isDestructive ? Colors.red : _textGrey),
      title: Text(
        label,
        style: TextStyle(
          color: isDestructive ? Colors.red : _textDark,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        if (index == -1) {
          _logout();
        } else {
          _navigate(index);
        }
      },
    );
  }

  Widget _buildHeader() {
    final nombre = (_profile?['nombre'] as String?)?.trim();
    final saludo = (nombre == null || nombre.isEmpty) ? 'Hola, conductor' : 'Hola, ${nombre.split(' ').first}';
    return FondoDegradado(
      colores: const [_primaryBlue, _accentBlue],
      radio: const BorderRadius.vertical(bottom: Radius.circular(24)),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 18),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 26),
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  ),
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    child: Text(
                      _initials(nombre),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(saludo,
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis),
                        Text(_statusLabel(),
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
                      ],
                    ),
                  ),
                  if (_activeTrip != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _accentGreen.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('Viaje activo',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              _buildOnlineToggle(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOnlineToggle() {
    // Con la cuenta suspendida por pago no se puede conectar (sí desconectar).
    final bloqueado = !_online && _estadoPago.bloqueaConexion;
    final subtitulo = _online
        ? 'Recibiendo solicitudes cercanas'
        : bloqueado
            ? (_estadoPago == EstadoPagoConductor.enRevision
                ? 'Pago en revisión: aún no puedes conectarte'
                : 'Suspendido por pago: paga para conectarte')
            : 'No recibirás solicitudes';
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _online ? const Color(0xFF4ADE80) : Colors.white38,
              boxShadow: _online
                  ? [BoxShadow(color: const Color(0xFF4ADE80).withValues(alpha: 0.6), blurRadius: 8)]
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_online ? 'Conectado' : 'Desconectado',
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                Text(subtitulo,
                    key: const Key('subtitulo_conexion'),
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12)),
              ],
            ),
          ),
          if (_statusLoading)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
            )
          else
            Switch(
              value: _online,
              onChanged: bloqueado ? null : (_) => _toggleStatus(),
              activeThumbColor: Colors.white,
              activeTrackColor: _accentGreen,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: Colors.white24,
            ),
        ],
      ),
    );
  }

  Widget _buildActiveTripCard({EdgeInsets margen = const EdgeInsets.all(16)}) {
    final t = _activeTrip!;
    final origen = t['origen'] as Map<String, dynamic>?;
    final destino = t['destino'] as Map<String, dynamic>?;
    final cliente = t['cliente'] as Map<String, dynamic>?;
    final nombre = cliente?['nombre'] as String? ?? 'Cliente';
    final estado = t['estado'] as String? ?? '';
    String estadoLabel;
    switch (estado) {
      case TripStatus.aceptado: estadoLabel = 'Aceptado'; break;
      case TripStatus.enCamino: estadoLabel = 'En camino'; break;
      case TripStatus.llegada: estadoLabel = 'Llegada al origen'; break;
      case TripStatus.enCurso: estadoLabel = 'En curso'; break;
      case TripStatus.entregado: estadoLabel = 'Entregado'; break;
      case TripStatus.esperaConfirmacion: estadoLabel = 'Esperando confirmación'; break;
      case TripStatus.pendienteConfirmacion: estadoLabel = 'Esperando confirmación del cliente'; break;
      case TripStatus.reservado: estadoLabel = 'Reservado'; break;
      default: estadoLabel = 'Activo';
    }

    return Padding(
      padding: margen,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF1A3C6E), Color(0xFF1565C0)]),
              borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 16, offset: const Offset(0, 6))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: _accentGreen.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.trip_origin, size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(estadoLabel, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                  const Spacer(),
                  Text('ID: ${t['id']}', style: const TextStyle(color: Colors.white60, fontSize: 11)),
                ]),
                const SizedBox(height: 20),
                Row(children: [
                  const Icon(Icons.person, color: Colors.white70, size: 18),
                  const SizedBox(width: 8),
                  Text(nombre, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 16),
                _buildRouteRow(Icons.circle_outlined, 'Salida', origen?['direccion'] as String? ?? ''),
                const SizedBox(height: 10),
                _buildRouteRow(Icons.location_on_outlined, 'Llegada', destino?['direccion'] as String? ?? ''),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () => _abrirViaje(t),
                    icon: const Icon(Icons.map_rounded, size: 22),
                    label: const Text('Ver viaje en el mapa', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: _primaryBlue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteRow(IconData icon, String label, String address) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 16, color: Colors.white60),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
          Text(address, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
        ]),
      ),
    ]);
  }

  /// Orden del inicio: viaje pendiente de confirmación (si lo hay) → UN solo
  /// aviso → solicitudes disponibles → resumen del día → mapa plegable.
  /// "Documentos", "Mis viajes", etc. viven en el menú lateral, el perfil y
  /// la barra inferior (antes había una fila de "Accesos rápidos" repetida).
  Widget _buildHomeContent() {
    if (_viajeOcupa) {
      return _buildActiveTripCard();
    }
    final aviso = _avisoPrincipal();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Viaje que espera la confirmación del cliente: visible sin
          // bloquear el resto del inicio.
          if (_activeTrip != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _buildActiveTripCard(margen: EdgeInsets.zero),
            ),
          if (aviso != null) aviso,
          SolicitudesDisponiblesSection(
            online: _online,
            cargandoConexion: _statusLoading,
            onConectar: _toggleStatus,
            maximo: _maxSolicitudesInicio,
            onVerTodas: () => _navigate(14),
          ),
          const SizedBox(height: 16),
          _buildStatsRow(),
          const SizedBox(height: 12),
          _MapaPlegable(online: _online),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// Si hay varios motivos de aviso se muestra sólo el más importante:
  /// 1. bloqueo por pago (suspendida o comprobante en revisión),
  /// 2. registro de conductor incompleto (sólo con el perfil ya cargado:
  ///    mientras carga no se sabe y antes salía "Completa tu registro"),
  /// 3. verificación pendiente o rechazada,
  /// 4. deuda de comisión sin bloqueo.
  Widget? _avisoPrincipal() {
    final pago = _estadoPago;
    if (pago.bloqueaConexion) {
      // "¿Ya pagaste? Escríbele a soporte": ticket de pagos con el asunto listo.
      return AvisoCuentaPago(
        deuda: _deuda,
        onAbrirPagos: _abrirPagos,
        onSoporte: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const NuevoTicketScreen(
              categoriaInicial: 'pago',
              asuntoInicial: 'Ya pagué y mi cuenta sigue suspendida',
            ),
          ),
        ),
      );
    }
    final perfilCargado = _profile != null;
    if (perfilCargado && _profile!['conductor'] == null) {
      return _AvisoRegistro(
        key: const Key('aviso_registro_incompleto'),
        icono: Icons.person_add_alt_1,
        color: const Color(0xFF1D4ED8),
        titulo: 'Completa tu registro como conductor',
        detalle: 'Sube tus documentos para empezar a recibir viajes.',
        onTap: () => _navigate(10),
      );
    }
    final estado = _verificacionEstado;
    if (estado == 'rechazado' || estado == 'pendiente') {
      return _AvisoRegistro(
        key: const Key('aviso_verificacion'),
        icono: Icons.verified_outlined,
        color: const Color(0xFFEA580C),
        titulo: estado == 'rechazado' ? 'Tu verificación fue rechazada' : 'Verificación pendiente',
        detalle: estado == 'rechazado'
            ? 'Revisa tus documentos y vuelve a enviarlos.'
            : 'Estamos revisando tus documentos. Te avisaremos cuando estés aprobado.',
        onTap: () => _navigate(10),
      );
    }
    if (pago == EstadoPagoConductor.conDeuda) return AvisoCuentaPago(deuda: _deuda, onAbrirPagos: _abrirPagos);
    return null;
  }

  num? _num(dynamic v) => v == null ? null : num.tryParse(v.toString());

  String _money(num? v) => formatearPesos(v ?? 0);

  /// Resumen del día en una sola fila compacta: ganancias · viajes · calificación.
  Widget _buildStatsRow() {
    final rating = _num(_stats?['calificacion']);
    return TarjetaBlanca(
      key: const Key('resumen_dia'),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
      child: IntrinsicHeight(
        child: Row(
          children: [
            _statCompacta(Icons.payments_rounded, _money(_num(_stats?['netaHoy'])), 'Hoy', const Color(0xFF16A34A)),
            const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFE5E7EB)),
            _statCompacta(Icons.local_shipping_rounded, '${_num(_stats?['viajesHoy'])?.toInt() ?? 0}', 'Viajes', _accentBlue),
            const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFE5E7EB)),
            _statCompacta(Icons.star_rounded, rating == null || rating == 0 ? '—' : rating.toStringAsFixed(1),
                'Calificación', const Color(0xFFF59E0B)),
          ],
        ),
      ),
    );
  }

  Widget _statCompacta(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 4),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _textDark)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11, color: _textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  String _initials(String? name) {
    if (name == null || name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name[0].toUpperCase();
  }
}

/// Aviso de registro incompleto o verificación pendiente/rechazada: lleva a
/// Documentación.
class _AvisoRegistro extends StatelessWidget {
  final IconData icono;
  final Color color;
  final String titulo;
  final String detalle;
  final VoidCallback onTap;

  const _AvisoRegistro({
    super.key,
    required this.icono,
    required this.color,
    required this.titulo,
    required this.detalle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                Icon(icono, color: color, size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titulo, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
                      const SizedBox(height: 3),
                      Text(detalle, style: const TextStyle(fontSize: 12.5, color: Color(0xFF374151), height: 1.35)),
                      const SizedBox(height: 4),
                      Text('Ir a Documentación', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Tu ubicación": mini mapa pequeño que el conductor puede plegar (se
/// recuerda entre sesiones).
class _MapaPlegable extends StatefulWidget {
  final bool online;
  const _MapaPlegable({required this.online});

  static const String _preferencia = 'inicio_mapa_plegado';

  @override
  State<_MapaPlegable> createState() => _MapaPlegableState();
}

class _MapaPlegableState extends State<_MapaPlegable> {
  late bool _plegado = CacheService.instance.getPreference(_MapaPlegable._preferencia) == true;

  void _alternar() {
    setState(() => _plegado = !_plegado);
    CacheService.instance.setPreference(_MapaPlegable._preferencia, _plegado);
  }

  @override
  Widget build(BuildContext context) {
    return TarjetaBlanca(
      padding: EdgeInsets.zero,
      radio: 18,
      child: Column(
        children: [
          InkWell(
            key: const Key('alternar_mapa'),
            borderRadius: BorderRadius.circular(18),
            onTap: _alternar,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
              child: Row(
                children: [
                  const Icon(Icons.map_outlined, size: 18, color: Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Tu ubicación en el mapa',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
                  ),
                  Icon(_plegado ? Icons.expand_more_rounded : Icons.expand_less_rounded, color: const Color(0xFF6B7280)),
                ],
              ),
            ),
          ),
          if (!_plegado)
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
              child: _DriverMiniMap(online: widget.online),
            ),
        ],
      ),
    );
  }
}

/// Mini mapa de la posición del conductor. Aislado en su propio widget para
/// que el refresco periódico de la posición (cada 10 s) sólo reconstruya el
/// mapa y lo mueva con [MapController] en vez de reconstruir la pantalla
/// completa y recrear el FlutterMap (tiles incluidos) con un ValueKey nuevo.
class _DriverMiniMap extends StatefulWidget {
  final bool online;
  const _DriverMiniMap({required this.online});

  @override
  State<_DriverMiniMap> createState() => _DriverMiniMapState();
}

class _DriverMiniMapState extends State<_DriverMiniMap> {
  static const Color _accentBlue = Color(0xFF2563EB);
  static const Color _textDark = Color(0xFF1A1A2E);
  static const _interaction = InteractionOptions(flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag);

  final MapController _mapController = MapController();
  Timer? _timer;
  LatLng? _pos;
  bool _mapReady = false;

  // Se crea con la primera posición: el mapa no se dibuja hasta tenerla (antes
  // mostraba Cali mientras buscaba el GPS, lejos de donde está el conductor).
  late final MapOptions _options = MapOptions(
    initialCenter: _pos!,
    initialZoom: 15,
    interactionOptions: _interaction,
    onMapReady: () => _mapReady = true,
  );
  late final Widget _tiles = TileLayer(urlTemplate: MapConfig.tileUrl, userAgentPackageName: 'com.cargaexpress.app');

  @override
  void initState() {
    super.initState();
    _pos = _read();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  LatLng? _read() {
    final lat = DriverLocationService.instance.lastLat;
    final lng = DriverLocationService.instance.lastLng;
    return lat != null && lng != null ? LatLng(lat, lng) : null;
  }

  void _refresh() {
    if (!mounted) return;
    final next = _read();
    if (next == null || next == _pos) return; // sin cambios: no reconstruir
    setState(() => _pos = next);
    if (_mapReady) _mapController.move(next, _mapController.camera.zoom);
  }

  @override
  Widget build(BuildContext context) {
    final pos = _pos;
    final tienePosicion = pos != null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: 160,
        child: Stack(
          children: [
            if (pos == null)
              Positioned.fill(
                key: const Key('mini_mapa_sin_posicion'),
                child: Container(
                  color: const Color(0xFFE5E7EB),
                  alignment: Alignment.center,
                  child: Icon(Icons.map_outlined, size: 48, color: Colors.grey.shade400),
                ),
              )
            else
              FlutterMap(
                mapController: _mapController,
                options: _options,
                children: [
                  _tiles,
                  MarkerLayer(markers: [
                    Marker(
                      point: pos,
                      width: 44,
                      height: 44,
                      child: Container(
                        decoration: BoxDecoration(
                          color: _accentBlue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [BoxShadow(color: _accentBlue.withValues(alpha: 0.45), blurRadius: 12, spreadRadius: 3)],
                        ),
                        child: const Icon(Icons.local_shipping, color: Colors.white, size: 20),
                      ),
                    ),
                  ]),
                ],
              ),
            if (!widget.online)
              Positioned.fill(
                child: Container(
                  color: Colors.white.withValues(alpha: 0.65),
                  alignment: Alignment.center,
                  child: const Text('Conéctate para recibir viajes cerca de ti',
                      style: TextStyle(fontWeight: FontWeight.w600, color: _textDark)),
                ),
              ),
            Positioned(
              left: 12,
              top: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 6)],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(tienePosicion ? Icons.my_location : Icons.location_searching, size: 14, color: _accentBlue),
                  const SizedBox(width: 6),
                  Text(tienePosicion ? 'Tu ubicación' : 'Buscando tu ubicación...',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _textDark)),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
