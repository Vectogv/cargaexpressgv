import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import 'viaje_detalle_screen.dart';

class MisEnviosScreen extends StatefulWidget {
  const MisEnviosScreen({super.key});

  @override
  State<MisEnviosScreen> createState() => _MisEnviosScreenState();
}

class _MisEnviosScreenState extends State<MisEnviosScreen> {
  List<Map<String, dynamic>> _viajes = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiClient.instance.getTripHistory();
      if (mounted) setState(() { _viajes = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  String _estadoLabel(String estado) {
    switch (estado) {
      case 'buscando_conductor': return 'Buscando conductor';
      case 'aceptado': return 'Aceptado';
      case 'en_curso': return 'En curso';
      case 'esperando_confirmacion': return 'Esperando confirmación';
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
      case 'esperando_confirmacion':
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
        title: const Text('Mis envíos', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                        const SizedBox(height: 12),
                        Text('Error al cargar envíos', style: TextStyle(color: Colors.grey[600])),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : _viajes.isEmpty
                  ? const Center(child: Text('No tienes envíos', style: TextStyle(color: Colors.black45)))
                  : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _viajes.length,
                    itemBuilder: (_, i) => _buildCard(_viajes[i]),
                  ),
                ),
    );
  }

  Widget _buildCard(Map<String, dynamic> v) {
    final origen = v['origen'] as Map<String, dynamic>?;
    final destino = v['destino'] as Map<String, dynamic>?;
    final estado = v['estado'] as String? ?? '';
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ViajeDetalleScreen(tripId: v['id']))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: _estadoColor(estado).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text(_estadoLabel(estado), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _estadoColor(estado))),
                ),
                const Spacer(),
                Text(_formatDate(v['createdAt'] as String?), style: const TextStyle(fontSize: 11, color: Colors.black45)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.trip_origin, size: 14, color: Color(0xFF1E88E5)),
                const SizedBox(width: 6),
                Expanded(child: Text(origen?['direccion'] as String? ?? '', style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on, size: 14, color: Color(0xFF4CAF50)),
                const SizedBox(width: 6),
                Expanded(child: Text(destino?['direccion'] as String? ?? '', style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            ),
            if (v['precioEstimado'] != null) ...[
              const SizedBox(height: 6),
              Text('\$${(v['precioEstimado'] as num).toStringAsFixed(0)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1A3C6E))),
            ],
          ],
        ),
      ),
    );
  }
}
