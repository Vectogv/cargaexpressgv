import 'dart:async';

import 'package:flutter/material.dart';
import '../../contracts/cancelacion.dart';
import '../../contracts/trip_status.dart';
import '../../contracts/socket_events.dart';
import '../../widgets/carga_express_bottom_nav.dart';
import '../../services/api_client.dart';
import '../../services/api/payment_service.dart';
import '../../services/cache_service.dart';
import '../../services/notification_service.dart';
import '../../services/socket_service_client.dart';
import '../user/auth_screen.dart';
import '../conductor/notifications_screen.dart';
import 'cliente_inicio_view.dart';
import 'nuevo_envio_screen.dart';
import 'mis_envios_screen.dart';
import 'rastreo_screen.dart';
import 'perfil_screen.dart';
import 'pagos_screen.dart';
import 'soporte_screen.dart';
import 'ajustes_screen.dart';
import 'viaje_detalle_screen.dart';

class ClienteHomeScreen extends StatefulWidget {
  const ClienteHomeScreen({super.key});

  @override
  State<ClienteHomeScreen> createState() => _ClienteHomeScreenState();
}

class _ClienteHomeScreenState extends State<ClienteHomeScreen> with WidgetsBindingObserver {
  static const Color _primaryBlue = Color(0xFF2563EB);
  static const Color _textDark = Color(0xFF1A1A2E);
  static const Color _textGrey = Color(0xFF757575);
  static const Color _white = Colors.white;

  int _selectedNavIndex = 0;

  Map<String, dynamic>? _activeTrip;
  bool _loading = true;
  bool _errorActivo = false;
  List<Map<String, dynamic>> _recientes = [];
  bool _cargandoRecientes = true;
  bool _errorRecientes = false;
  bool _redirected = false;
  // Pagos sólo aparece si hay deuda (GET /api/payments).
  bool _tieneDeuda = false;
  bool _suspendidoPorPago = false;
  StreamSubscription<Map<String, dynamic>>? _socketSub;
  // Resolución de disputa y verificación de pago cambian la deuda y el
  // estado de los envíos: se refresca sin esperar a que el cliente recargue.
  final List<StreamSubscription<Map<String, dynamic>>> _cuentaSubs = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadActiveTrip();
    _loadRecientes();
    _loadDeuda();
    NotificationService.instance.refresh();

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
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
        if (mounted) {
          setState(() { _activeTrip = trip; _loading = false; _errorActivo = false; });
          // Un viaje en disputa sigue "activo" en el backend, pero no hay nada
          // que rastrear: no se fuerza la redireccion (evita que "Volver al
          // inicio" rebote de nuevo al seguimiento). La tarjeta lo muestra.
          final enDisputa = trip['estado'] == TripStatus.disputa ||
              trip['estado'] == TripStatus.enDisputa;
          if (!_redirected && !enDisputa) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _redirectToTracking());
          }
        }
      } else {
        CacheService.instance.clearActiveTrip();
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
          _tieneDeuda = tieneDeudaPendiente(info);
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
      if (recargar && mounted) _refrescar();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _white,
      drawer: _buildDrawer(),
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
                onPerfil: () => _abrir(const PerfilScreen()),
                onSoporte: () => _abrir(const SoporteScreen()),
                onReintentar: _refrescar,
                onRefresh: _refrescar,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CargaExpressBottomNav(
        currentIndex: _selectedNavIndex,
        items: [
          (icon: Icons.home_rounded, label: 'Inicio', onTap: () {
            setState(() => _selectedNavIndex = 0);
          }),
          (icon: Icons.person_outline_rounded, label: 'Perfil', onTap: () {
            setState(() => _selectedNavIndex = 1);
            _onNavTap(1);
          }),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
      child: Row(
        children: [
          Builder(builder: (ctx) {
            return IconButton(
              tooltip: 'Menú',
              onPressed: () => Scaffold.of(ctx).openDrawer(),
              icon: const Icon(Icons.menu_rounded, color: _textDark),
            );
          }),
          Builder(builder: (ctx) {
            return GestureDetector(
              onTap: () => Scaffold.of(ctx).openDrawer(),
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
                  const Text(
                    'CargaExpress',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            );
          }),
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

  void _onNavTap(int index) {
    switch (index) {
      case 0:
        break;
      case 1:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const PerfilScreen()));
        break;
    }
  }

  Widget _buildDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              color: _primaryBlue,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white24,
                    child: const Icon(Icons.person, color: Colors.white, size: 30),
                  ),
                  const SizedBox(height: 12),
                  Text(ApiClient.instance.nombreCompleto, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(ApiClient.instance.email ?? '', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            _buildDrawerItem(Icons.person_outline, 'Perfil', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PerfilScreen()))),
            _buildDrawerItem(Icons.route_outlined, 'Mis viajes', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MisEnviosScreen()))),
            if (_tieneDeuda)
              _buildDrawerItem(Icons.payments_outlined, 'Pagos', _abrirPagos,
                  destacado: _suspendidoPorPago ? 'Pendiente' : null),
            _buildDrawerItem(Icons.support_agent, 'Soporte', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SoporteScreen()))),
            _buildDrawerItem(Icons.settings_outlined, 'Ajustes', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AjustesScreen()))),
            const Spacer(),
            const Divider(),
            _buildDrawerItem(Icons.logout, 'Cerrar sesi\u00f3n', _logout, isDestructive: true),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String label, VoidCallback? onTap,
      {bool isDestructive = false, String? destacado}) {
    return ListTile(
      leading: Icon(icon, color: isDestructive ? Colors.red : (destacado != null ? const Color(0xFFB91C1C) : _textGrey)),
      title: Text(label, style: TextStyle(color: isDestructive ? Colors.red : _textDark)),
      trailing: destacado == null
          ? null
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(20)),
              child: Text(destacado,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFFB91C1C))),
            ),
      onTap: () {
        Navigator.pop(context);
        if (onTap != null) onTap();
      },
    );
  }

  Future<void> _logout() async {
    await ApiClient.instance.logout();
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const AuthScreen()), (_) => false);
    });
  }
}

