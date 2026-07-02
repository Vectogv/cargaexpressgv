import 'dart:async';
import 'package:flutter/material.dart';
import '../../contracts/trip_status.dart';
import '../../services/api_client.dart';
import '../../services/socket_service_client.dart';
import '../../models/trip.dart';
import 'trip_in_progress_screen.dart';

class OffersScreen extends StatefulWidget {
  const OffersScreen({super.key});

  @override
  State<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends State<OffersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _activeTrip;
  List<Map<String, dynamic>> _history = [];
  bool _loadingActive = true;
  bool _loadingHistory = true;

  StreamSubscription<Map<String, dynamic>>? _offerAcceptedSub;

  static const Color _primaryBlue = Color(0xFF1565C0);
  static const Color _accentGreen = Color(0xFF4CAF50);
  static const Color _textDark = Color(0xFF1A1A2E);
  static const Color _textGrey = Color(0xFF757575);
  static const Color _bgLight = Color(0xFFF5F7FA);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchData();
    _offerAcceptedSub = SocketServiceClient.instance.onOfferAccepted.listen((_) {
      if (mounted) _fetchData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _offerAcceptedSub?.cancel();
    super.dispose();
  }

  Future<void> _fetchData() async {
    await Future.wait([_fetchActive(), _fetchHistory()]);
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
            Tab(text: 'Viaje activo'),
            Tab(text: 'Historial'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildActiveTab(),
          _buildHistoryTab(),
        ],
      ),
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
      case TripStatus.esperaConfirmacion: c = _accentGreen; label = 'Esperando confirmación'; break;
      case TripStatus.finalizado: c = _accentGreen; label = 'Finalizado'; break;
      default: c = Colors.grey; label = estado; break;
    }
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: c.withValues(alpha: 0.3))),
      child: Row(children: [
        Icon(Icons.info_outline, size: 18, color: c),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: c, fontSize: 13)),
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
      case TripStatus.esperaConfirmacion: c = _primaryBlue; label = 'Esperando confirmación'; break;
      case TripStatus.finalizado: c = _accentGreen; label = 'Finalizado'; break;
      case TripStatus.cancelado: c = Colors.red; label = 'Cancelado'; break;
      default: c = _textGrey; label = estado; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w600)),
    );
  }
}
