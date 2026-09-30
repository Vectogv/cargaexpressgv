import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../core/formato_dinero.dart';
import '../shared/ui_compartida.dart';
import '../cliente/viaje_detalle_screen.dart';

class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({super.key});

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  final List<Map<String, dynamic>> _history = [];
  final ScrollController _scrollCtrl = ScrollController();
  bool _loading = true;
  bool _loadingMore = false;
  int _page = 1;
  bool _hasMore = true;
  static const int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
            _scrollCtrl.position.maxScrollExtent - 200 &&
        !_loadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    _page++;
    await _fetchHistory(isLoadMore: true);
    if (mounted) setState(() => _loadingMore = false);
  }

  Future<void> _fetchHistory({bool isLoadMore = false}) async {
    if (!isLoadMore) setState(() => _loading = true);
    try {
      final data = await ApiClient.instance.getTripHistory(
        page: _page,
        limit: _pageSize,
      );
      if (mounted) {
        setState(() {
          _history.addAll(data);
          _hasMore = data.length >= _pageSize;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColoresApp.fondo,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: ColoresApp.textoOscuro,
        elevation: 0,
        title: const Text(
          'Historial de viajes',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  const Text(
                    'Sin viajes anteriores',
                    style: TextStyle(fontSize: 16, color: Colors.black45),
                  ),
                ],
              ),
            )
          : ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(16),
              itemCount: _history.length + (_hasMore ? 1 : 0),
              itemBuilder: (_, i) {
                if (i == _history.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
                if (i == _history.length && _loadingMore) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
                return _buildTripCard(_history[i]);
              },
            ),
    );
  }

  Widget _buildTripCard(Map<String, dynamic> t) {
    final origen = t['origen'] as Map<String, dynamic>?;
    final destino = t['destino'] as Map<String, dynamic>?;
    final estado = t['estado'] as String? ?? '';
    final precio =
        (t['precioFinal'] as num?) ?? (t['precioEstimado'] as num?) ?? 0;
    final id = t['id'] ?? t['_id'];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: id == null
            ? null
            : () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ViajeDetalleScreen(tripId: id, comoConductor: true),
                ),
              ),
        child: TarjetaBlanca(
          radio: 14,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _estadoBadge(estado),
                  const Spacer(),
                  Text(
                    formatearPesos(precio),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                origen?['direccion'] as String? ?? '',
                style: const TextStyle(fontSize: 13),
              ),
              Text(
                destino?['direccion'] as String? ?? '',
                style: const TextStyle(
                  fontSize: 13,
                  color: ColoresApp.textoSecundario,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    _formatDate(t['createdAt'] as String?),
                    style: TextStyle(
                      fontSize: 11,
                      color: ColoresApp.textoSecundario,
                    ),
                  ),
                  const Spacer(),
                  if (estado == 'finalizado')
                    Text(
                      'Neto: ${formatearPesos(precio - (precio * 0.1 * 100).round() / 100)}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: ColoresApp.verde,
                      ),
                    ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: ColoresApp.chevron,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _estadoBadge(String estado) {
    Color c;
    String label;
    switch (estado) {
      case 'finalizado':
        c = ColoresApp.verde;
        label = 'Finalizado';
        break;
      case 'esperando_confirmacion':
        c = ColoresApp.azulOscuro;
        label = 'Esperando confirmación';
        break;
      case 'reservado':
        c = ColoresApp.textoSecundario;
        label = 'Reservado';
        break;
      case 'cancelado':
        c = Colors.red;
        label = 'Cancelado';
        break;
      default:
        c = ColoresApp.textoSecundario;
        label = estado;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w600),
      ),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}
