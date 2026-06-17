import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/api_client.dart';
import '../../services/map_config.dart';
import '../../services/proximity_service.dart';

class RastreoScreen extends StatefulWidget {
  const RastreoScreen({super.key});

  @override
  State<RastreoScreen> createState() => _RastreoScreenState();
}

class _RastreoScreenState extends State<RastreoScreen> {
  Map<String, dynamic>? _trip;
  List<Map<String, dynamic>> _offers = [];
  bool _loading = true;
  bool _mapError = false;
  Timer? _pollTimer;
  Timer? _refreshTimer;
  final ProximityService _proximityService = ProximityService();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _refreshTimer?.cancel();
    _proximityService.stopMonitoring();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final trip = await ApiClient.instance.getActiveTrip();
      if (mounted) setState(() { _trip = trip; _loading = false; _mapError = false; });
      if (trip != null) {
        if (trip['estado'] == 'buscando_conductor') {
          _pollOffers(trip['id']);
        }
        _proximityService.startMonitoring(trip, _showProximityAlert);
        _startRefreshTimer();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startRefreshTimer() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) => _refreshTrip());
  }

  Future<void> _refreshTrip() async {
    if (_trip == null) return;
    try {
      final trip = await ApiClient.instance.getActiveTrip();
      if (mounted && trip != null) {
        final oldEstado = _trip!['estado'] as String?;
        setState(() { _trip = trip; _mapError = false; });
        final newEstado = trip['estado'] as String?;
        if (newEstado != oldEstado && (newEstado == 'cancelado' || newEstado == 'completado' || newEstado == 'finalizado')) {
          _proximityService.stopMonitoring();
          _snack('Viaje ${newEstado == 'cancelado' ? 'cancelado' : 'finalizado'}');
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) Navigator.pop(context);
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _pollOffers(dynamic tripId) async {
    try {
      final offers = await ApiClient.instance.getOffers(tripId);
      if (mounted) setState(() => _offers = offers);
    } catch (_) {}
    _pollTimer = Timer(const Duration(seconds: 5), () => _pollOffers(tripId));
  }

  Future<void> _aceptarOferta(dynamic offerId) async {
    try {
      await ApiClient.instance.acceptOffer(_trip!['id'], offerId);
    } catch (e) {
      if (mounted) _snack('Error: ${e.toString().replaceFirst("Exception: ", "")}');
    }
  }

  Future<void> _cancelar() async {
    final motivoCtrl = TextEditingController();
    String? motivoSeleccionado;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Cancelar viaje'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.orange.shade200)),
                child: Row(children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Esta acci\u00f3n ser\u00e1 revisada por el equipo de soporte.', style: TextStyle(fontSize: 13, color: Colors.orange.shade900, fontWeight: FontWeight.w500))),
                ]),
              ),
              const SizedBox(height: 16),
              const Text('Motivo de cancelaci\u00f3n:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 8),
              ...['Problema con el conductor', 'Cambio de planes', 'Tiempo de espera muy largo', 'Otro'].map((m) => RadioListTile<String>(
                title: Text(m, style: const TextStyle(fontSize: 14)),
                value: m,
                groupValue: motivoSeleccionado,
                onChanged: (v) => setDialogState(() => motivoSeleccionado = v),
                dense: true,
                contentPadding: EdgeInsets.zero,
              )),
              if (motivoSeleccionado != null) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: motivoCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Describe el problema (opcional)',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(12),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Volver')),
            ElevatedButton(
              onPressed: motivoSeleccionado == null ? null : () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, foregroundColor: Colors.white),
              child: const Text('Cancelar viaje'),
            ),
          ],
        ),
      ),
    );

    if (confirmado != true || motivoSeleccionado == null) return;

    try {
      await ApiClient.instance.cancelTrip(_trip!['id'], motivo: motivoSeleccionado);
      if (mounted) {
        _snack('Viaje cancelado. Se ha notificado al conductor.');
        _proximityService.stopMonitoring();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) _snack('Error: ${e.toString().replaceFirst("Exception: ", "")}');
    }
  }

  void _showProximityAlert(String message) {
    if (!mounted) return;
    _snack(message);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aviso de proximidad'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido')),
        ],
      ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _buildMap(Map<String, dynamic> origen, Map<String, dynamic> destino) {
    final oLat = double.tryParse(origen['lat']?.toString() ?? '') ?? 0;
    final oLng = double.tryParse(origen['lng']?.toString() ?? '') ?? 0;
    final dLat = double.tryParse(destino['lat']?.toString() ?? '') ?? 0;
    final dLng = double.tryParse(destino['lng']?.toString() ?? '') ?? 0;
    final center = LatLng((oLat + dLat) / 2, (oLng + dLng) / 2);

    if (_mapError) {
      return _buildMapError();
    }

    return Container(
      height: 200,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE0E0E0))),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          FlutterMap(
            options: MapOptions(initialCenter: center, initialZoom: 12),
            children: [
              TileLayer(urlTemplate: MapConfig.tileUrl, userAgentPackageName: 'com.cargaexpress.app', errorImage: const AssetImage('')),
              MarkerLayer(markers: [
                Marker(point: LatLng(oLat, oLng), width: 36, height: 36, child: const Icon(Icons.trip_origin, color: Colors.green, size: 36)),
                Marker(point: LatLng(dLat, dLng), width: 36, height: 36, child: const Icon(Icons.location_on, color: Colors.red, size: 36)),
              ]),
            ],
          ),
          Positioned(
            right: 8, top: 8,
            child: Material(
              elevation: 2,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: () => setState(() => _mapError = false),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.refresh, size: 18, color: Color(0xFF1A3C6E)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapError() {
    return Container(
      height: 200,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE0E0E0)), color: const Color(0xFFF5F5F5)),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            const Text('No se pudo cargar el mapa', style: TextStyle(fontSize: 14, color: Colors.black54)),
            const SizedBox(height: 4),
            Text('Verifica tu conexi\u00f3n a internet', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => setState(() => _mapError = false),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Reintentar', style: TextStyle(fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A3C6E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  String _estadoLabel(String? estado) {
    switch (estado) {
      case 'buscando_conductor': return 'Buscando conductor';
      case 'aceptado': return 'Conductor asignado';
      case 'en_curso': return 'En camino a destino';
      case 'completado': return 'Entrega completada';
      case 'finalizado': return 'Finalizado';
      case 'cancelado': return 'Cancelado';
      default: return estado ?? '';
    }
  }

  Color _estadoColor(String? estado) {
    switch (estado) {
      case 'buscando_conductor': return const Color(0xFFFF9800);
      case 'aceptado': return const Color(0xFF1E88E5);
      case 'en_curso': return const Color(0xFF1565C0);
      case 'completado': return const Color(0xFF4CAF50);
      case 'finalizado': return const Color(0xFF2E7D32);
      case 'cancelado': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Color(0xFF1A1A2E)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Rastrear viaje', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _trip == null
              ? const Center(child: Text('No tienes un viaje activo', style: TextStyle(fontSize: 15, color: Colors.black45)))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final estado = _trip!['estado'] as String?;
    final origen = _trip!['origen'] as Map<String, dynamic>?;
    final destino = _trip!['destino'] as Map<String, dynamic>?;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (origen != null && destino != null) _buildMap(origen, destino),
          const SizedBox(height: 16),
          if (estado == 'buscando_conductor')
            _buildRadarSearch()
          else
            _buildStatusCard(estado),
          const SizedBox(height: 16),
          _buildRouteCard(origen, destino),
          const SizedBox(height: 16),
          if (estado == 'buscando_conductor') _buildOffersSection(),
          if (estado == 'aceptado' || estado == 'en_curso') _buildDriverCard(),
          if (estado == 'buscando_conductor')
            Center(
              child: TextButton.icon(
                onPressed: _cancelar,
                icon: const Icon(Icons.cancel_outlined, color: Colors.red, size: 20),
                label: const Text('Cancelar viaje', style: TextStyle(color: Colors.red)),
              ),
            ),
          if (estado == 'aceptado' || estado == 'en_curso')
            Center(
              child: TextButton.icon(
                onPressed: _cancelar,
                icon: const Icon(Icons.cancel_outlined, color: Colors.red, size: 20),
                label: const Text('Cancelar viaje', style: TextStyle(color: Colors.red)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRadarSearch() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFFFF3E0), Color(0xFFFFF8E1)],
              begin: Alignment.topCenter, end: Alignment.bottomCenter),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFF8F00).withOpacity(0.3)),
          ),
          child: Column(
            children: [
              _RadarAnimation(),
              const SizedBox(height: 16),
              const Text(
                'Buscando conductor',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E)),
              ),
              const SizedBox(height: 6),
              Text(
                'Notificando a conductores cercanos...',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 200, height: 44,
                child: ElevatedButton.icon(
                  onPressed: _cancelar,
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: const Text('Cancelar viaje', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildTipsCard(),
      ],
    );
  }

  Widget _buildTipsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.lightbulb_outline, size: 18, color: const Color(0xFFFF8F00)),
            const SizedBox(width: 8),
            const Text('Recomendaciones', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
          ]),
          const SizedBox(height: 12),
          _tipRow(Icons.checklist_rtl, 'Verifica que tus pertenencias est\u00e9n completas'),
          const SizedBox(height: 8),
          _tipRow(Icons.photo_camera_outlined, 'Toma una foto del viaje y del veh\u00edculo al llegar'),
          const SizedBox(height: 8),
          _tipRow(Icons.shield_outlined, 'Confirma que los datos del conductor coincidan'),
        ],
      ),
    );
  }

  Widget _tipRow(IconData icon, String text) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        margin: const EdgeInsets.only(top: 2),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(6)),
        child: Icon(icon, size: 16, color: const Color(0xFF1565C0)),
      ),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: Color(0xFF424242)))),
    ]);
  }

  Widget _buildStatusCard(String? estado) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _estadoColor(estado).withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _estadoColor(estado).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.circle, color: _estadoColor(estado), size: 14),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _estadoLabel(estado),
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _estadoColor(estado)),
            ),
          ),
          if (estado == 'buscando_conductor')
            const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)),
        ],
      ),
    );
  }

  Widget _buildRouteCard(Map<String, dynamic>? origen, Map<String, dynamic>? destino) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ruta', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black45)),
          const SizedBox(height: 10),
          Row(
            children: [
              Column(children: [
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF1E88E5), shape: BoxShape.circle)),
                Container(width: 1.5, height: 20, color: Colors.grey.shade300),
                Container(width: 8, height: 8, decoration: BoxDecoration(border: Border.all(color: const Color(0xFF4CAF50), width: 2), shape: BoxShape.circle)),
              ]),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(origen?['direccion'] as String? ?? 'Sin direcci\u00f3n', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 14),
                    Text(destino?['direccion'] as String? ?? 'Sin direcci\u00f3n', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOffersSection() {
    if (_offers.isEmpty) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(20),
        child: Text('Esperando ofertas de conductores...', style: TextStyle(color: Colors.black45)),
      ));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Ofertas recibidas', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        ..._offers.map((offer) => _buildOfferCard(offer)),
      ],
    );
  }

  Widget _buildOfferCard(Map<String, dynamic> offer) {
    final conductor = offer['conductor'] as Map<String, dynamic>?;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFF1A3C6E),
            child: Text(
              _initials(conductor?['nombre'] as String? ?? ''),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(conductor?['nombre'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                Text('${conductor?['tipoVehiculo'] ?? ''} \u00b7 ${offer['placa'] ?? conductor?['placa'] ?? ''}', style: const TextStyle(fontSize: 12, color: Colors.black45)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('\$${(offer['monto'] as num?)?.toStringAsFixed(0) ?? '0'}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1A3C6E))),
              const SizedBox(height: 4),
              SizedBox(
                height: 28,
                child: ElevatedButton(
                  onPressed: () => _aceptarOferta(offer['id']),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: const Text('Aceptar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDriverCard() {
    final conductor = _trip!['conductor'] as Map<String, dynamic>?;
    if (conductor == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tu conductor', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black45)),
          const SizedBox(height: 10),
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFFE0E0E0),
                child: Text(
                  _initials(conductor['nombre'] as String? ?? ''),
                  style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(conductor['nombre'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('${conductor['tipoVehiculo'] ?? ''} \u00b7 ${conductor['placa'] ?? ''}', style: const TextStyle(fontSize: 12, color: Colors.black45)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RadarAnimation extends StatefulWidget {
  @override
  State<_RadarAnimation> createState() => _RadarAnimationState();
}

class _RadarAnimationState extends State<_RadarAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
    _pulse = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    _ctrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, child) => SizedBox(
        width: 130, height: 130,
        child: Stack(
          alignment: Alignment.center,
          children: [
            _ring(1.0, 0.08),
            _ring(0.7, 0.14),
            _ring(0.4, 0.22),
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                gradient: const SweepGradient(colors: [Color(0xFFFF8F00), Color(0xFFFFB74D), Color(0xFFFF8F00)]),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: const Color(0xFFFF8F00).withOpacity(0.4), blurRadius: 12, spreadRadius: 2)],
              ),
              child: const Icon(Icons.radar, color: Colors.white, size: 28),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ring(double factor, double baseOpacity) {
    final size = 56 + (1 - _pulse.value) * 70 * factor;
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFFF8F00).withOpacity(baseOpacity * (1 - _pulse.value * 0.6)),
      ),
    );
  }
}
