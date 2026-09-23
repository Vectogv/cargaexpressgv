import 'dart:async';
import 'package:flutter/material.dart';
import '../../contracts/trip_status.dart';
import '../../services/api_client.dart';
import '../../services/socket_service_client.dart';
import '../../models/oferta_pendiente.dart';
import '../../models/trip.dart';
import '../../services/server_clock.dart';
import 'oferta_aceptada_screen.dart';
import 'trip_in_progress_screen.dart';

class OffersScreen extends StatefulWidget {
  const OffersScreen({super.key});

  @override
  State<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends State<OffersScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  Map<String, dynamic>? _activeTrip;
  List<Map<String, dynamic>> _history = [];
  bool _loadingActive = true;
  bool _loadingHistory = true;

  /// Ofertas enviadas que esperan respuesta del cliente.
  List<OfertaPendiente> _pendientes = [];
  bool _loadingPendientes = true;
  String? _errorPendientes;
  Timer? _relojPendientes;
  bool _abriendoViaje = false;

  StreamSubscription<Map<String, dynamic>>? _offerAcceptedSub;
  StreamSubscription<Map<String, dynamic>>? _offerRejectedSub;
  StreamSubscription<Map<String, dynamic>>? _offerExpiredSub;

  static const Color _primaryBlue = Color(0xFF1565C0);
  static const Color _accentGreen = Color(0xFF4CAF50);
  static const Color _textDark = Color(0xFF1A1A2E);
  static const Color _textGrey = Color(0xFF757575);
  static const Color _bgLight = Color(0xFFF5F7FA);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addObserver(this);
    _fetchData();
    _offerAcceptedSub = SocketServiceClient.instance.onOfferAccepted.listen(_ofertaAceptada);
    _offerRejectedSub = SocketServiceClient.instance.onOfferRejected.listen(_quitarOferta);
    _offerExpiredSub = SocketServiceClient.instance.onOfferExpired.listen(_quitarOferta);
    // La cuenta regresiva se recalcula con la hora del servidor cada segundo.
    _relojPendientes = Timer.periodic(const Duration(seconds: 1), (_) => _descartarVencidas());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    _offerAcceptedSub?.cancel();
    _offerRejectedSub?.cancel();
    _offerExpiredSub?.cancel();
    _relojPendientes?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) _fetchPendientes();
  }

  Future<void> _fetchData() async {
    await Future.wait([_fetchPendientes(), _fetchActive(), _fetchHistory()]);
  }

  Future<void> _fetchPendientes() async {
    if (mounted && _errorPendientes != null) {
      setState(() { _errorPendientes = null; _loadingPendientes = true; });
    }
    try {
      final lista = await ApiClient.instance.getMyPendingOffers();
      final ahora = ServerClock.ahora();
      final ofertas = lista
          .map(OfertaPendiente.fromJson)
          .where((o) => o.restante(ahora) != Duration.zero)
          .toList();
      if (mounted) setState(() { _pendientes = ofertas; _loadingPendientes = false; _errorPendientes = null; });
    } catch (_) {
      if (mounted) {
        setState(() { _loadingPendientes = false; _errorPendientes = 'No se pudieron cargar tus ofertas'; });
      }
    }
  }

  void _descartarVencidas() {
    if (!mounted || _pendientes.isEmpty) return;
    final ahora = ServerClock.ahora();
    setState(() => _pendientes = _pendientes.where((o) => o.restante(ahora) != Duration.zero).toList());
  }

  void _quitarOferta(Map<String, dynamic> evento) {
    if (!mounted) return;
    setState(() => _pendientes = _pendientes.where((o) => !o.coincideCon(evento)).toList());
  }

  /// El cliente aceptó una oferta: se abre el viaje como desde "Oferta enviada".
  Future<void> _ofertaAceptada(Map<String, dynamic> evento) async {
    if (!mounted) return;
    OfertaPendiente? aceptada;
    for (final o in _pendientes) {
      if (o.coincideCon(evento)) aceptada = o;
    }
    if (aceptada == null || _abriendoViaje) {
      _fetchData();
      return;
    }
    _abriendoViaje = true;
    setState(() => _pendientes = _pendientes.where((o) => o != aceptada).toList());
    final monto = evento['monto'] is num ? evento['monto'] as num : aceptada.monto;
    Map<String, dynamic> viaje;
    try {
      viaje = await ApiClient.instance.getTripDetail(aceptada.viajeId);
    } catch (_) {
      viaje = {'id': aceptada.viajeId, ...evento};
    }
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(
      builder: (_) => OfertaAceptadaScreen.desdeViaje(viaje, montoOferta: _dinero(monto)),
    ));
  }

  static String _dinero(num n) {
    final s = n.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
    return '\$$s';
  }

  Future<void> _fetchActive() async {
    try {
      final trip = await ApiClient.instance.getActiveTrip();
      if (mounted) setState(() { _activeTrip = trip; _loadingActive = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingActive = false);
    }
  }

  Future<void> _fetchHistory() async {
    try {
      final res = await ApiClient.instance.getTripHistory(limit: 50);
      if (mounted) setState(() { _history = res; _loadingHistory = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        backgroundColor: Colors.white, foregroundColor: _textDark, elevation: 0,
        title: const Text('Mis ofertas', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _primaryBlue,
          labelColor: _primaryBlue,
          unselectedLabelColor: _textGrey,
          tabs: const [
            Tab(text: 'Pendientes'),
            Tab(text: 'Viaje activo'),
            Tab(text: 'Historial'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPendientesTab(),
          _buildActiveTab(),
          _buildHistoryTab(),
        ],
      ),
    );
  }

  /// Lista deslizable (para "tirar hacia abajo" también en vacío o error).
  Widget _mensajePendientes(IconData icono, String titulo, String detalle, {Widget? accion}) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
      children: [
        Icon(icono, size: 64, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        Text(titulo, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: Colors.black45)),
        const SizedBox(height: 6),
        Text(detalle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Colors.black38)),
        if (accion != null) ...[const SizedBox(height: 16), Center(child: accion)],
      ],
    );
  }

  Widget _buildPendientesTab() {
    if (_loadingPendientes) return const Center(child: CircularProgressIndicator());
    final Widget contenido;
    if (_errorPendientes != null) {
      contenido = _mensajePendientes(
        Icons.cloud_off, _errorPendientes!, 'Revisa tu conexión e intenta de nuevo.',
        accion: OutlinedButton.icon(
          onPressed: _fetchPendientes,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Reintentar'),
        ),
      );
    } else if (_pendientes.isEmpty) {
      contenido = _mensajePendientes(
        Icons.local_offer_outlined, 'No tienes ofertas pendientes',
        'Las ofertas que envíes aparecerán aquí mientras el cliente decide.',
      );
    } else {
      final ahora = ServerClock.ahora();
      contenido = ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _pendientes.length,
        itemBuilder: (_, i) => _pendienteCard(_pendientes[i], ahora),
      );
    }
    return RefreshIndicator(onRefresh: _fetchPendientes, child: contenido);
  }

  Widget _pendienteCard(OfertaPendiente o, DateTime ahora) {
    final restante = o.restante(ahora);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: const Color(0xFFFF8F00).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.timer_outlined, size: 14, color: Color(0xFFFF8F00)),
              const SizedBox(width: 4),
              Text(
                restante != null ? 'Vence en ${formatoCuentaRegresiva(restante)}' : 'Esperando al cliente',
                style: const TextStyle(fontSize: 12, color: Color(0xFFFF8F00), fontWeight: FontWeight.w700),
              ),
            ]),
          ),
          const Spacer(),
          Text(_dinero(o.monto), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          const Icon(Icons.trip_origin, size: 16, color: _accentGreen),
          const SizedBox(width: 8),
          Expanded(child: Text(o.origen, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          const Icon(Icons.location_on, size: 16, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(child: Text(o.destino, style: const TextStyle(fontSize: 13, color: _textGrey))),
        ]),
      ]),
    );
  }

  Widget _buildActiveTab() {
    if (_loadingActive) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_activeTrip == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_shipping, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text('Sin viaje activo', style: TextStyle(fontSize: 16, color: Colors.black45)),
            const SizedBox(height: 6),
            const Text('Tus ofertas aceptadas aparecerán aquí', style: TextStyle(fontSize: 13, color: Colors.black38)),
          ],
        ),
      );
    }
    final t = _activeTrip!;
    final origen = t['origen'] as Map<String, dynamic>?;
    final destino = t['destino'] as Map<String, dynamic>?;
    final estado = t['estado'] as String? ?? '';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _statusBanner(estado),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Ruta', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black45)),
              const SizedBox(height: 10),
              Row(children: [
                Icon(Icons.trip_origin, size: 16, color: _accentGreen),
                const SizedBox(width: 8),
                Expanded(child: Text(origen?['direccion'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w500))),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.location_on, size: 16, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(child: Text(destino?['direccion'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w500))),
              ]),
              const SizedBox(height: 12),
              Text('Carga: ${t['carga'] as String? ?? ''}', style: const TextStyle(color: _textGrey)),
              Text('Precio: \$${(t['precioFinal'] as num? ?? t['precioEstimado'] as num?)?.toStringAsFixed(0) ?? '0'}', style: const TextStyle(fontWeight: FontWeight.w700)),
            ]),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TripInProgressScreen(trip: _activeTrip != null ? Trip.fromJson(_activeTrip!) : null))),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBlue, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Ir al viaje', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBanner(String estado) {
    Color c;
    String label;
    switch (estado) {
      case TripStatus.aceptado: c = const Color(0xFFFF8F00); label = 'Aceptado — Dirígete al origen'; break;
      case TripStatus.enCamino: c = const Color(0xFFFF8F00); label = 'En camino al origen'; break;
      case TripStatus.llegada: c = _accentGreen; label = 'Llegada al origen'; break;
      case TripStatus.enCurso: c = _primaryBlue; label = 'En curso — Realizando entrega'; break;
      case TripStatus.entregado: c = _accentGreen; label = 'Entregado'; break;
      case TripStatus.esperaConfirmacion:
      case TripStatus.pendienteConfirmacion: c = _accentGreen; label = 'Esperando confirmación del cliente'; break;
      case TripStatus.finalizado: c = _accentGreen; label = 'Finalizado'; break;
      case TripStatus.reservado: c = Colors.grey; label = 'Reservado'; break;
      default: c = Colors.grey; label = TripStatus.label(estado); break;
    }
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: c.withValues(alpha: 0.3))),
      child: Row(children: [
        Icon(Icons.info_outline, size: 18, color: c),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: c, fontSize: 13))),
      ]),
    );
  }

  Widget _buildHistoryTab() {
    if (_loadingHistory) return const Center(child: CircularProgressIndicator());
    if (_history.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text('Sin viajes anteriores', style: TextStyle(fontSize: 16, color: Colors.black45)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _history.length,
      itemBuilder: (_, i) => _historyCard(_history[i]),
    );
  }

  Widget _historyCard(Map<String, dynamic> t) {
    final origen = t['origen'] as Map<String, dynamic>?;
    final destino = t['destino'] as Map<String, dynamic>?;
    final estado = t['estado'] as String? ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _estadoBadge(estado),
          const Spacer(),
          Text('\$${(t['precioFinal'] as num? ?? t['precioEstimado'] as num?)?.toStringAsFixed(0) ?? '0'}', style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 8),
        Text(origen?['direccion'] as String? ?? '', style: const TextStyle(fontSize: 13)),
        Text(destino?['direccion'] as String? ?? '', style: const TextStyle(fontSize: 13, color: _textGrey)),
      ]),
    );
  }

  Widget _estadoBadge(String estado) {
    Color c;
    String label;
    switch (estado) {
      case TripStatus.aceptado: c = const Color(0xFFFF8F00); label = 'Aceptado'; break;
      case TripStatus.enCamino: c = const Color(0xFFFF8F00); label = 'En camino'; break;
      case TripStatus.llegada: c = _accentGreen; label = 'Llegada'; break;
      case TripStatus.enCurso: c = _primaryBlue; label = 'En curso'; break;
      case TripStatus.entregado: c = _accentGreen; label = 'Entregado'; break;
      case TripStatus.esperaConfirmacion:
      case TripStatus.pendienteConfirmacion: c = _primaryBlue; label = 'Esperando confirmación'; break;
      case TripStatus.finalizado: c = _accentGreen; label = 'Finalizado'; break;
      case TripStatus.reservado: c = _textGrey; label = 'Reservado'; break;
      case TripStatus.cancelado: c = Colors.red; label = 'Cancelado'; break;
      default: c = _textGrey; label = TripStatus.label(estado); break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w600)),
    );
  }
}
