import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../services/api_client.dart';

class ViajesScreen extends StatefulWidget {
  const ViajesScreen({super.key});

  @override
  State<ViajesScreen> createState() => _ViajesScreenState();
}

class _ViajesScreenState extends State<ViajesScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _viajes = [];
  String _filtro = 'todos';

  int _tabIndex = 0;
  List<Map<String, dynamic>> _solicitudes = [];
  bool _loadingSolicitudes = false;

  static const _estados = [
    {'key': 'todos', 'label': 'Todos'},
    {'key': 'pendiente', 'label': 'Pendiente'},
    {'key': 'aceptado', 'label': 'Aceptado'},
    {'key': 'en_curso', 'label': 'En Curso'},
    {'key': 'completado', 'label': 'Completado'},
    {'key': 'cancelado', 'label': 'Cancelado'},
  ];

  Map<String, String> get _authHeaders => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${ApiClient.instance.token}',
  };

  @override
  void initState() {
    super.initState();
    _fetchViajes();
  }

  Future<void> _fetchViajes() async {
    setState(() => _loading = true);
    try {
      final res = await http.get(
        Uri.parse('${ApiClient.baseUrl}/api/admin/trips'),
        headers: _authHeaders,
      );
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        if (mounted) setState(() { _viajes = List<Map<String, dynamic>>.from(data); _loading = false; });
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchSolicitudes() async {
    setState(() => _loadingSolicitudes = true);
    try {
      final res = await http.get(
        Uri.parse('${ApiClient.baseUrl}/api/admin/cancellation-requests'),
        headers: _authHeaders,
      );
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        if (mounted) setState(() { _solicitudes = List<Map<String, dynamic>>.from(data); _loadingSolicitudes = false; });
      } else {
        if (mounted) setState(() => _loadingSolicitudes = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingSolicitudes = false);
    }
  }

  Future<void> _aprovarSolicitud(dynamic tripId) async {
    try {
      await http.post(
        Uri.parse('${ApiClient.baseUrl}/api/admin/cancellation-requests/$tripId/approve'),
        headers: _authHeaders,
      );
      if (mounted) {
        _snack('Viaje cancelado');
        _fetchSolicitudes();
        _fetchViajes();
      }
    } catch (_) {
      if (mounted) _snack('Error al aprobar cancelación');
    }
  }

  Future<void> _rechazarSolicitud(dynamic tripId) async {
    try {
      await http.post(
        Uri.parse('${ApiClient.baseUrl}/api/admin/cancellation-requests/$tripId/reject'),
        headers: _authHeaders,
      );
      if (mounted) {
        _snack('Solicitud rechazada');
        _fetchSolicitudes();
        _fetchViajes();
      }
    } catch (_) {
      if (mounted) _snack('Error al rechazar solicitud');
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _onTabChanged(int i) {
    setState(() => _tabIndex = i);
    if (i == 1 && _solicitudes.isEmpty) {
      _fetchSolicitudes();
    }
  }

  List<Map<String, dynamic>> get _filtrados {
    if (_filtro == 'todos') return _viajes;
    return _viajes.where((v) => v['estado'] == _filtro).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F7),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            if (_tabIndex == 0) _buildFiltros(),
            Expanded(child: _tabIndex == 0 ? _buildViajesTab() : _buildSolicitudesTab()),
          ],
        ),
      ),
    );
  }

  Widget _buildViajesTab() {
    return _loading
        ? const Center(child: CircularProgressIndicator())
        : _filtrados.isEmpty
            ? const Center(child: Text('Sin viajes', style: TextStyle(color: Colors.black45)))
            : RefreshIndicator(
                onRefresh: _fetchViajes,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: _filtrados.length,
                  itemBuilder: (_, i) => _ViajeCard(viaje: _filtrados[i]),
                ),
              );
  }

  Widget _buildSolicitudesTab() {
    return _loadingSolicitudes
        ? const Center(child: CircularProgressIndicator())
        : _solicitudes.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline, size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    const Text('No hay solicitudes de cancelación pendientes', style: TextStyle(color: Colors.black45)),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: _fetchSolicitudes,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  itemCount: _solicitudes.length,
                  itemBuilder: (_, i) => _SolicitudCancelacionCard(
                    solicitud: _solicitudes[i],
                    onApprove: () => _aprovarSolicitud(_solicitudes[i]['tripId'] ?? _solicitudes[i]['id']),
                    onReject: () => _rechazarSolicitud(_solicitudes[i]['tripId'] ?? _solicitudes[i]['id']),
                  ),
                ),
              );
  }

  Widget _buildTopBar() {
    return Container(
      color: const Color(0xFFF2F3F7),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.black87, size: 26),
                onPressed: () => Navigator.maybePop(context),
              ),
              const Text('VIAJES / SERVICIOS', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87, letterSpacing: 0.3)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.black45, size: 20),
                onPressed: _tabIndex == 0 ? _fetchViajes : _fetchSolicitudes,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _onTabChanged(0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _tabIndex == 0 ? Colors.black87 : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Viajes',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: _tabIndex == 0 ? Colors.white : Colors.black54,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _onTabChanged(1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _tabIndex == 1 ? Colors.black87 : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Solicitudes de cancelación',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: _tabIndex == 1 ? Colors.white : Colors.black54,
                        ),
                      ),
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

  Widget _buildFiltros() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _estados.length,
        itemBuilder: (_, i) {
          final selected = _filtro == _estados[i]['key'];
          return GestureDetector(
            onTap: () => setState(() => _filtro = _estados[i]['key']!),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? Colors.black87 : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [if (!selected) BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)],
              ),
              child: Text(
                _estados[i]['label']!,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? Colors.white : Colors.black54),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ViajeCard extends StatelessWidget {
  final Map<String, dynamic> viaje;

  const _ViajeCard({required this.viaje});

  String _estadoLabel(String estado) {
    switch (estado) {
      case 'pendiente': return 'Pendiente';
      case 'aceptado': return 'Aceptado';
      case 'en_curso': return 'En Curso';
      case 'completado': return 'Completado';
      case 'finalizado': return 'Finalizado';
      case 'cancelado': return 'Cancelado';
      default: return estado;
    }
  }

  Color _estadoColor(String estado) {
    switch (estado) {
      case 'pendiente': return const Color(0xFFE53935);
      case 'aceptado': return const Color(0xFF1E88E5);
      case 'en_curso': return const Color(0xFFFB8C00);
      case 'completado':
      case 'finalizado': return const Color(0xFF43A047);
      case 'cancelado': return Colors.black38;
      default: return Colors.black38;
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
    final conductor = viaje['conductor'] as Map<String, dynamic>?;
    final cliente = viaje['cliente'] as Map<String, dynamic>?;
    final estado = viaje['estado'] as String? ?? '';
    final origen = viaje['origenDireccion'] as String? ?? '';
    final destino = viaje['destinoDireccion'] as String? ?? '';
    final carga = viaje['carga'] as String? ?? '';
    final precioEstimado = viaje['precioEstimado'];
    final precioFinal = viaje['precioFinal'];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _estadoColor(estado).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _estadoColor(estado).withValues(alpha: 0.35), width: 1),
                  ),
                  child: Text(
                    _estadoLabel(estado),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _estadoColor(estado)),
                  ),
                ),
                const Spacer(),
                Text(_formatDate(viaje['createdAt'] as String?), style: const TextStyle(fontSize: 11, color: Colors.black45)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(
              children: [
                _buildRoute(origen, destino),
              ],
            ),
          ),
          if (carga.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Row(
                children: [
                  const Icon(Icons.inventory_outlined, size: 14, color: Colors.black38),
                  const SizedBox(width: 4),
                  Text(carga, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Row(
              children: [
                if (precioEstimado != null)
                  Text('\$${(precioEstimado as num).toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1A3C6E))),
                if (precioEstimado != null && precioFinal != null) const SizedBox(width: 4),
                if (precioFinal != null)
                  Text('\$${(precioFinal as num).toStringAsFixed(0)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF4CAF50))),
              ],
            ),
          ),
          const Divider(height: 20, indent: 14, endIndent: 14),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Row(
              children: [
                if (conductor != null) ...[
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: const Color(0xFFE0E0E0),
                    child: Text(
                      _initials('${conductor['nombre'] ?? ''} ${conductor['apellido'] ?? ''}'),
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${conductor['nombre'] ?? ''} ${conductor['apellido'] ?? ''}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 4),
                  Text('· ${conductor['placa'] ?? ''}', style: const TextStyle(fontSize: 11, color: Colors.black45)),
                ] else
                  const Text('Sin conductor asignado', style: TextStyle(fontSize: 12, color: Colors.black38)),
                const Spacer(),
                if (cliente != null)
                  Text(cliente['nombre'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.black45)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoute(String origen, String destino) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: const Color(0xFFF7F7F7), borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Column(
            children: [
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF1E88E5), shape: BoxShape.circle)),
              Container(width: 1.5, height: 16, color: const Color(0xFFBDBDBD)),
              Container(width: 8, height: 8, decoration: BoxDecoration(border: Border.all(color: const Color(0xFF43A047), width: 2), shape: BoxShape.circle)),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(origen.isNotEmpty ? origen : 'Sin origen', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87)),
                const SizedBox(height: 8),
                Text(destino.isNotEmpty ? destino : 'Sin destino', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

class _SolicitudCancelacionCard extends StatelessWidget {
  final Map<String, dynamic> solicitud;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _SolicitudCancelacionCard({
    required this.solicitud,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final conductor = solicitud['conductor'] as Map<String, dynamic>?;
    final tripId = solicitud['tripId'] ?? solicitud['id'];
    final motivo = solicitud['motivo'] as String? ?? 'Sin motivo especificado';
    final origen = solicitud['origenDireccion'] as String? ?? '';
    final destino = solicitud['destinoDireccion'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.orange.shade200, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(Icons.report_problem_outlined, color: Colors.orange, size: 18),
                const SizedBox(width: 8),
                const Text('Solicitud de cancelación', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.orange)),
                const Spacer(),
                Text('#$tripId', style: const TextStyle(fontSize: 11, color: Colors.black45)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(
              children: [
                if (conductor != null) ...[
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: const Color(0xFFE0E0E0),
                    child: Text(
                      _initials('${conductor['nombre'] ?? ''} ${conductor['apellido'] ?? ''}'),
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${conductor['nombre'] ?? ''} ${conductor['apellido'] ?? ''}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ],
            ),
          ),
          if (origen.isNotEmpty || destino.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Row(
                children: [
                  Icon(Icons.route_outlined, size: 14, color: Colors.black38),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${origen.isNotEmpty ? origen : '?'} → ${destino.isNotEmpty ? destino : '?'}',
                      style: const TextStyle(fontSize: 11, color: Colors.black54),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          Container(
            margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.comment_outlined, size: 16, color: Colors.grey.shade500),
                const SizedBox(width: 8),
                Expanded(child: Text(motivo, style: const TextStyle(fontSize: 12, color: Colors.black87))),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Divider(height: 1),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: OutlinedButton.icon(
                      onPressed: onReject,
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Rechazar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: ElevatedButton.icon(
                      onPressed: onApprove,
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Aprobar y cancelar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
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

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}
