import 'package:flutter/material.dart';
import '../../services/api_client.dart';

class ViajeDetalleScreen extends StatefulWidget {
  final dynamic tripId;
  const ViajeDetalleScreen({super.key, required this.tripId});

  @override
  State<ViajeDetalleScreen> createState() => _ViajeDetalleScreenState();
}

class _ViajeDetalleScreenState extends State<ViajeDetalleScreen> {
  Map<String, dynamic>? _trip;
  bool _loading = true;
  int _rating = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiClient.instance.getTripDetail(widget.tripId);
      if (mounted) setState(() { _trip = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _calificar() async {
    if (_rating == 0) return;
    try {
      await ApiClient.instance.rateTrip(widget.tripId, _rating);
      if (mounted) _snack('Calificación guardada');
    } catch (e) {
      if (mounted) _snack('Error: ${e.toString().replaceFirst("Exception: ", "")}');
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _estadoLabel(String estado) {
    switch (estado) {
      case 'buscando_conductor': return 'Buscando conductor';
      case 'aceptado': return 'Aceptado';
      case 'en_curso': return 'En curso';
      case 'completado': return 'Completado';
      case 'finalizado': return 'Finalizado';
      case 'cancelado': return 'Cancelado';
      default: return estado;
    }
  }

  Color _estadoColor(String estado) {
    switch (estado) {
      case 'buscando_conductor': return const Color(0xFFFF9800);
      case 'aceptado': return const Color(0xFF1E88E5);
      case 'en_curso': return const Color(0xFF1565C0);
      case 'completado':
      case 'finalizado': return const Color(0xFF4CAF50);
      case 'cancelado': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
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
        title: const Text('Detalle del viaje', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _trip == null
              ? const Center(child: Text('Viaje no encontrado', style: TextStyle(color: Colors.black45)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatusSection(),
                      const SizedBox(height: 16),
                      _buildRouteSection(),
                      const SizedBox(height: 16),
                      _buildInfoSection(),
                      if (_trip!['conductor'] != null) ...[
                        const SizedBox(height: 16),
                        _buildConductorSection(),
                      ],
                      if (_trip!['estado'] == 'finalizado') ...[
                        const SizedBox(height: 16),
                        _buildRatingSection(),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _buildStatusSection() {
    final estado = _trip!['estado'] as String? ?? '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _estadoColor(estado).withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _estadoColor(estado).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.circle, color: _estadoColor(estado), size: 12),
              const SizedBox(width: 8),
              Text(_estadoLabel(estado), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _estadoColor(estado))),
            ],
          ),
          const SizedBox(height: 8),
          _timestampRow('Creado', _trip!['createdAt'] as String?),
          _timestampRow('Aceptado', _trip!['aceptadoAt'] as String?),
          _timestampRow('En curso', _trip!['enCursoAt'] as String?),
          _timestampRow('Completado', _trip!['completadoAt'] as String?),
          _timestampRow('Finalizado', _trip!['finalizadoAt'] as String?),
          if (_trip!['canceladoAt'] != null) _timestampRow('Cancelado', _trip!['canceladoAt'] as String?),
        ],
      ),
    );
  }

  Widget _timestampRow(String label, String? iso) {
    if (iso == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          const SizedBox(width: 20),
          Text('$label: ', style: const TextStyle(fontSize: 12, color: Colors.black45)),
          Text(_formatDate(iso), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildRouteSection() {
    final origen = _trip!['origen'] as Map<String, dynamic>?;
    final destino = _trip!['destino'] as Map<String, dynamic>?;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ruta', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black45)),
          const SizedBox(height: 10),
          Row(children: [
            Column(children: [
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF1E88E5), shape: BoxShape.circle)),
              Container(width: 1.5, height: 20, color: Colors.grey.shade300),
              Container(width: 8, height: 8, decoration: BoxDecoration(border: Border.all(color: const Color(0xFF4CAF50), width: 2), shape: BoxShape.circle)),
            ]),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(origen?['direccion'] as String? ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 14),
              Text(destino?['direccion'] as String? ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ])),
          ]),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Información', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black45)),
          const SizedBox(height: 10),
          if (_trip!['carga'] != null && (_trip!['carga'] as String).isNotEmpty)
            _infoRow('Carga', _trip!['carga'] as String),
          _infoRow('Precio estimado', '\$${(_trip!['precioEstimado'] as num?)?.toStringAsFixed(0) ?? '-'}'),
          _infoRow('Precio final', '\$${(_trip!['precioFinal'] as num?)?.toStringAsFixed(0) ?? '-'}'),
          if (_trip!['motivoCancelacion'] != null)
            _infoRow('Motivo cancelación', _trip!['motivoCancelacion'] as String),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.black45)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildConductorSection() {
    final conductor = _trip!['conductor'] as Map<String, dynamic>?;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Conductor', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black45)),
          const SizedBox(height: 10),
          Row(children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFFE0E0E0),
              child: Text(
                _initials(conductor!['nombre'] as String? ?? ''),
                style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(conductor['nombre'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('${conductor['tipoVehiculo'] ?? ''} · ${conductor['placa'] ?? ''}', style: const TextStyle(fontSize: 12, color: Colors.black45)),
            ])),
          ]),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  Widget _buildRatingSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Calificar viaje', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black45)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final star = i + 1;
              return IconButton(
                icon: Icon(star <= _rating ? Icons.star_rounded : Icons.star_border_rounded, color: const Color(0xFFFFC107), size: 36),
                onPressed: () => setState(() => _rating = star),
              );
            }),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _rating > 0 ? _calificar : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A3C6E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('Enviar calificación', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
