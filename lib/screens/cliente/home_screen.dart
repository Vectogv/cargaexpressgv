import 'dart:async';

import 'package:flutter/material.dart';
import '../../contracts/cancelacion.dart';
import '../../contracts/socket_events.dart';
import '../../core/formato_dinero.dart';
import '../../widgets/carga_express_bottom_nav.dart';
import '../../services/api_client.dart';
import '../../services/api/payment_service.dart';
import '../../services/banner_service.dart';
import '../../services/cache_service.dart';
import '../../services/config_cliente_service.dart';
import '../../services/notification_service.dart';
import '../../services/socket_service_client.dart';
import '../shared/action_key.dart';
import '../shared/ui_compartida.dart';
import '../conductor/notifications_screen.dart';
import 'cliente_inicio_view.dart';
import 'confirmar_entrega_screen.dart';
import 'nuevo_envio_screen.dart';
import 'mis_envios_screen.dart';
import 'rastreo_screen.dart';
import 'perfil_screen.dart';
import 'pagos_screen.dart';
import '../shared/tutorial_inicio.dart';
import 'soporte_screen.dart';
import 'viaje_detalle_screen.dart';
import 'viaje_finalizado.dart';

class ClienteHomeScreen extends StatefulWidget {
  const ClienteHomeScreen({super.key});

  @override
  State<ClienteHomeScreen> createState() => _ClienteHomeScreenState();
}

class _ClienteHomeScreenState extends State<ClienteHomeScreen> with WidgetsBindingObserver {
  static const Color _primaryBlue = Color(0xFF2563EB);
  static const Color _textDark = Color(0xFF1A1A2E);
  static const Color _textGrey = Color(0xFF757575);

  Map<String, dynamic>? _activeTrip;
  bool _loading = true;
  bool _errorActivo = false;
  List<Map<String, dynamic>> _recientes = [];
  bool _cargandoRecientes = true;
  bool _errorRecientes = false;
  bool _redirected = false;
  bool _suspendidoPorPago = false;
  StreamSubscription<Map<String, dynamic>>? _socketSub;
  // Resolución de disputa y verificación de pago cambian la deuda y el
  // estado de los envíos: se refresca sin esperar a que el cliente recargue.
  final List<StreamSubscription<Map<String, dynamic>>> _cuentaSubs = [];
  // El socket muere en segundo plano: con un viaje activo en la tarjeta se
  // relee su estado cada 20 s, como en el resto de la app.
  Timer? _sondeo;
  final ActionKey _confirmCloseKey = ActionKey();
  final ActionKey _rejectCloseKey = ActionKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadActiveTrip();
    _loadRecientes();
    _loadDeuda();
    NotificationService.instance.refresh();
    // Plazo de confirmación que muestra la tarjeta de entrega por confirmar.
    ConfigClienteService.instance.cargar();
    // Anuncio de la gerencia (Configuración → Banner en el panel): ventana, una vez al día.
    _mostrarAnuncio();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) mostrarTutorialSiToca(context, claveTutorialCliente, pasosTutorialCliente);
    });
    _sondeo = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted && _activeTrip != null && ModalRoute.of(context)?.isCurrent == true) _loadActiveTrip();
    });

    _socketSub = NotificationService.instance.onNotification.listen((event) {
      final tipo = event['__event'] as String?;

      if (tipo == SocketEvents.tripStatusChanged || tipo == SocketEvents.tripCancelled) {
        _loadActiveTrip();
        _loadRecientes();
      }

      if (tipo == SocketEvents.tripCancelled && mounted) {
        CacheService.instance.clearDriverPosition();
        final msg = mensajeViajeCancelado(event, miRol: ApiClient.instance.rol);
        // Con RastreoScreen encima, el aviso lo muestra esa pantalla.
        if (msg != null && ModalRoute.of(context)?.isCurrent == true) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        }
      }

      // Redirigir a RastreoScreen cuando llegan ofertas
      if (tipo == SocketEvents.newOffer && mounted && _activeTrip != null) {
        _redirectToTracking();
      }

    });

    final socket = SocketServiceClient.instance;
    for (final stream in [socket.onDisputeResolved, socket.onPaymentConfirmed, socket.onPaymentRejected]) {
      _cuentaSubs.add(stream.listen((_) {
        if (!mounted) return;
        _loadDeuda();
        _loadRecientes();
      }));
    }

  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadActiveTrip();
      _loadDeuda();
      // Si la app quedó abierta de un día para otro, el anuncio vuelve a salir.
      _mostrarAnuncio();
    }
  }

  void _mostrarAnuncio() {
    BannerService.instance.cargar().then((_) {
      if (mounted && ModalRoute.of(context)?.isCurrent == true) mostrarAnuncioDelDia(context);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sondeo?.cancel();
    _socketSub?.cancel();
    for (final s in _cuentaSubs) {
      s.cancel();
    }
    super.dispose();
  }

  Future<void> _loadActiveTrip() async {
    try {
      final trip = await ApiClient.instance.getActiveTrip();
      if (trip != null) {
        CacheService.instance.cacheActiveTrip(trip);
        // El inicio muestra el viaje activo en su tarjeta (estado, progreso,
        // PIN y confirmación de entrega): ya no se salta solo al rastreo.
        if (mounted) setState(() { _activeTrip = trip; _loading = false; _errorActivo = false; });
      } else {
        CacheService.instance.clearActiveTrip();
        // El viaje acaba de cerrarse (sin socket): que "Último envío" lo muestre.
        if (_activeTrip != null) _loadRecientes();
        if (mounted) setState(() { _activeTrip = null; _loading = false; _errorActivo = false; });
      }
    } catch (_) {
      if (mounted) setState(() { _loading = false; _errorActivo = true; });
    }
  }

  /// Últimos envíos para el inicio (el viaje activo ya tiene su tarjeta).
  Future<void> _loadRecientes() async {
    if (mounted) setState(() { _cargandoRecientes = _recientes.isEmpty; _errorRecientes = false; });
    try {
      final data = await ApiClient.instance.getTripHistory(limit: 6);
      final activoId = (_activeTrip?['_id'] ?? _activeTrip?['id'])?.toString();
      final lista = data
          .where((v) => activoId == null || (v['_id'] ?? v['id'])?.toString() != activoId)
          .take(5)
          .toList();
      if (mounted) setState(() { _recientes = lista; _cargandoRecientes = false; });
    } catch (_) {
      if (mounted) setState(() { _cargandoRecientes = false; _errorRecientes = _recientes.isEmpty; });
    }
  }

  /// Si falla, Pagos queda oculto (no se bloquea el inicio).
  Future<void> _loadDeuda() async {
    try {
      final info = await PaymentService.getDebtInfo();
      if (mounted) {
        setState(() {
          _suspendidoPorPago = cuentaSuspendidaPorPago(info);
        });
      }
    } catch (_) {}
  }

  void _abrirPagos() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const PagosScreen())).then((_) {
      if (mounted) _loadDeuda();
    });
  }

  Future<void> _refrescar() async {
    await Future.wait([_loadActiveTrip(), _loadRecientes(), _loadDeuda()]);
  }

  void _abrir(Widget screen, {bool recargar = false}) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen)).then((_) {
      if (!mounted) return;
      // El admin puede liberar la cuenta sin evento de socket: se relee siempre.
      recargar ? _refrescar() : _loadDeuda();
    });
  }

  /// Abre el rastreo sólo si el inicio está al frente y no se abrió ya: tras
  /// crear un envío, NuevoEnvio se reemplaza por RastreoScreen y la recarga
  /// del inicio (o una oferta por socket) no debe apilar un segundo rastreo.
  void _redirectToTracking() {
    if (!mounted || _redirected) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;
    _redirected = true;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RastreoScreen()),
    ).then((_) {
      _redirected = false;
      _loadActiveTrip();
    });
  }

  /// Confirmar o rechazar la entrega desde la tarjeta del inicio, con la
  /// misma pantalla y las mismas llamadas (POST /trips/:id/confirm-close)
  /// que usa el rastreo.
  void _confirmarEntrega({bool rechazar = false}) {
    final viaje = _activeTrip;
    if (viaje == null) return;
    final tripId = (viaje['_id'] ?? viaje['id']).toString();
    final precio = viaje['precioFinal'] ?? viaje['precioEstimado'];
    final monto = precio is num ? precio : num.tryParse(precio?.toString() ?? '');
    _abrir(
      ConfirmarEntregaScreen(
        montoFinal: monto == null ? null : 'Monto final: ${formatearPesos(monto)}',
        rechazarAlAbrir: rechazar,
        onConfirmar: () async {
          try {
            await ApiClient.instance.confirmClose(tripId, confirmar: true, idempotencyKey: _confirmCloseKey.keyFor(tripId));
            _confirmCloseKey.settle();
          } catch (e) {
            _confirmCloseKey.settle(e);
            rethrow;
          }
          if (!mounted) return;
          CacheService.instance.clearActiveTrip();
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => ViajeFinalizado(trip: viaje, conductor: Map<String, dynamic>.from(viaje['conductor'] as Map? ?? {}))),
            (r) => r.isFirst,
          );
        },
        // ConfirmarEntregaScreen muestra "Disputa abierta" y al volver el
        // inicio relee el viaje (queda en disputa).
        onRechazar: (motivo) async {
          try {
            await ApiClient.instance.confirmClose(tripId, confirmar: false, motivo: motivo, idempotencyKey: _rejectCloseKey.keyFor('$tripId|$motivo'));
            _rejectCloseKey.settle();
          } catch (e) {
            _rejectCloseKey.settle(e);
            rethrow;
          }
        },
      ),
      recargar: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColoresApp.fondo,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            if (_suspendidoPorPago) _buildAvisoPago(),
            Expanded(
              child: ClienteInicioView(
                nombre: ApiClient.instance.nombre,
                cargando: _loading,
                errorActivo: _errorActivo,
                viajeActivo: _activeTrip,
                recientes: _recientes,
                cargandoRecientes: _cargandoRecientes,
                errorRecientes: _errorRecientes,
                onNuevoEnvio: () => _abrir(const NuevoEnvioScreen(), recargar: true),
                onVerSeguimiento: () => _abrir(const RastreoScreen(), recargar: true),
                onVerViaje: (v) => _abrir(ViajeDetalleScreen(tripId: v['_id'] ?? v['id'])),
                onHistorial: () => _abrir(const MisEnviosScreen()),
                onConfirmarEntrega: _confirmarEntrega,
                onReportarProblema: () => _confirmarEntrega(rechazar: true),
                onReintentar: _refrescar,
                onRefresh: _refrescar,
              ),
            ),
          ],
        ),
      ),
      // Las otras pestañas abren su pantalla encima del inicio; al volver se
      // relee la deuda (el admin puede liberar la cuenta sin socket).
      bottomNavigationBar: CargaExpressBottomNav(
        currentIndex: 0,
        items: [
          (icon: Icons.home_rounded, label: 'Inicio', onTap: () {}),
          (icon: Icons.inventory_2_outlined, label: 'Mis envíos', onTap: () => _abrir(const MisEnviosScreen())),
          (icon: Icons.support_agent_rounded, label: 'Soporte', onTap: () => _abrir(const SoporteScreen())),
          (icon: Icons.person_outline_rounded, label: 'Perfil', onTap: () => _abrir(const PerfilScreen())),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _primaryBlue,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.local_shipping, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  text: 'Carga',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: _textDark, letterSpacing: -0.3),
                  children: [TextSpan(text: 'Express', style: TextStyle(color: _primaryBlue))],
                ),
              ),
              Text('Tu carga, en buenas manos', style: TextStyle(fontSize: 11, color: _textGrey)),
            ],
          ),
          const Spacer(),
          // Misma fuente que la pantalla de notificaciones.
          ValueListenableBuilder<int>(
            valueListenable: NotificationService.instance.unread,
            builder: (_, count, __) => _badgeIcon(
              Icons.notifications_outlined,
              count,
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
            ),
          ),
        ],
      ),
    );
  }

  /// Cuenta suspendida por pago: acceso directo a Pagos arriba del inicio.
  Widget _buildAvisoPago() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Material(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          key: const Key('aviso_pago_pendiente'),
          borderRadius: BorderRadius.circular(14),
          onTap: _abrirPagos,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: const Row(
              children: [
                Icon(Icons.payments_outlined, color: Color(0xFFB91C1C)),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tienes un pago pendiente',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF7F1D1D))),
                      SizedBox(height: 2),
                      Text('Tu cuenta está suspendida hasta que registres el pago.',
                          style: TextStyle(fontSize: 12.5, color: Color(0xFF7F1D1D))),
                    ],
                  ),
                ),
                SizedBox(width: 6),
                Text('Ir a pagos', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFB91C1C))),
                Icon(Icons.chevron_right_rounded, color: Color(0xFFB91C1C)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _badgeIcon(IconData icon, int count, VoidCallback? onTap) {
    return Stack(
      children: [
        IconButton(
          icon: Icon(icon, color: const Color(0xFF1A1A2E), size: 22),
          onPressed: onTap,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        if (count > 0)
          Positioned(
            right: 2, top: 2,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              child: Text(
                count > 9 ? '9+' : '$count',
                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
              ),
            ),
          ),
      ],
    );
  }

}

