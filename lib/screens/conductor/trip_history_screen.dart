import 'package:flutter/material.dart';
import '../../services/api_client.dart';

class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({super.key});

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Map<int, List<Map<String, dynamic>>> _history = {};
  final Map<int, ScrollController> _scrollCtrls = {};
  final Map<int, bool> _loading = {0: true, 1: true, 2: true};
  final Map<int, bool> _loadingMore = {0: false, 1: false, 2: false};
  final Map<int, int> _page = {0: 1, 1: 1, 2: 1};
  final Map<int, bool> _hasMore = {0: true, 1: true, 2: true};
  static const int _pageSize = 10;

  static const Color _primaryDark = Color(0xFF1A3C6E);
  static const Color _accentGreen = Color(0xFF4CAF50);
  static const Color _textDark = Color(0xFF1A1A2E);
  static const Color _textGrey = Color(0xFF757575);
  static const Color _bgLight = Color(0xFFF5F7FA);
  static const Color _white = Colors.white;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    for (var i = 0; i < 3; i++) {
      _history[i] = [];
      _scrollCtrls[i] = ScrollController()..addListener(() => _onScroll(i));
    }
    _fetchHistory(0);
    _fetchHistory(1);
    _fetchHistory(2);
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (final c in _scrollCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      setState(() {});
    }
  }

  void _onScroll(int tab) {
    final ctrl = _scrollCtrls[tab]!;
    if (ctrl.position.pixels >= ctrl.position.maxScrollExtent - 200 &&
        !(_loadingMore[tab] ?? false) && (_hasMore[tab] ?? false)) {
      _loadMore(tab);
    }
  }

  Future<void> _loadMore(int tab) async {
    _loadingMore[tab] = true;
    _page[tab] = (_page[tab] ?? 1) + 1;
    await _fetchHistory(tab, isLoadMore: true);
    if (mounted) setState(() => _loadingMore[tab] = false);
  }

  String _estadoFilter(int tab) {
    switch (tab) {
      case 0: return 'finalizado,completado';
      case 1: return 'cancelado,rechazado';
      case 2: return 'disputa';
      default: return '';
    }
  }

  Future<void> _fetchHistory(int tab, {bool isLoadMore = false}) async {
    if (!isLoadMore) _loading[tab] = true;
    try {
      final data = await ApiClient.instance.getTripHistory(
        page: _page[tab] ?? 1,
        limit: _pageSize,
        estado: _estadoFilter(tab),
      );
      if (mounted) setState(() {
        (_history[tab] ?? []).addAll(data);
        _hasMore[tab] = data.length >= _pageSize;
        _loading[tab] = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading[tab] = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        backgroundColor: _white,
        foregroundColor: _textDark,
        elevation: 0,
        title: const Text('Historial de viajes',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: _primaryDark,
          unselectedLabelColor: _textGrey,
          indicatorColor: _primaryDark,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const [
            Tab(text: 'Completados'),
            Tab(text: 'Cancelados'),
            Tab(text: 'Disputas'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: List.generate(3, (tab) => _buildTabContent(tab)),
      ),
    );
  }

  Widget _buildTabContent(int tab) {
    if (_loading[tab] == true && (_history[tab]?.isEmpty ?? true)) {
      return const Center(child: CircularProgressIndicator());
    }
    final items = _history[tab] ?? [];
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(_emptyLabel(tab),
                style: const TextStyle(fontSize: 16, color: Colors.black45)),
          ],
        ),
      );
    }
    return ListView.builder(
      controller: _scrollCtrls[tab],
      padding: const EdgeInsets.all(16),
      itemCount: items.length + ((_hasMore[tab] ?? false) ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == items.length) {
          return const Center(
              child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(strokeWidth: 2)));
        }
        return _buildTripCard(items[i]);
      },
    );
  }

  String _emptyLabel(int tab) {
    switch (tab) {
      case 0: return 'Sin viajes completados';
      case 1: return 'Sin viajes cancelados';
      case 2: return 'Sin disputas';
      default: return '';
    }
  }

  Widget _buildTripCard(Map<String, dynamic> t) {
    final origen = t['origen'] as Map<String, dynamic>?;
    final destino = t['destino'] as Map<String, dynamic>?;
    final estado = t['estado'] as String? ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: _white, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _estadoBadge(estado),
              const Spacer(),
              Text(
                  '\$${(t['precioFinal'] as num? ?? t['precioEstimado'] as num?)?.toStringAsFixed(0) ?? '0'}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          Text(origen?['direccion'] as String? ?? '',
              style: const TextStyle(fontSize: 13)),
          Text(destino?['direccion'] as String? ?? '',
              style: const TextStyle(fontSize: 13, color: _textGrey)),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(_formatDate(t['createdAt'] as String?),
                  style: TextStyle(fontSize: 11, color: _textGrey)),
              const Spacer(),
              Text(
                  'Comisión: \$${(t['comision'] as num?)?.toStringAsFixed(0) ?? '-'}',
                  style: TextStyle(fontSize: 11, color: Colors.red.shade400)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _estadoBadge(String estado) {
    Color c;
    String label;
    switch (estado) {
      case 'finalizado':
        c = _accentGreen;
        label = 'Finalizado';
        break;
      case 'completado':
        c = _primaryDark;
        label = 'Completado';
        break;
      case 'cancelado':
        c = Colors.red;
        label = 'Cancelado';
        break;
      case 'rechazado':
        c = Colors.orange;
        label = 'Rechazado';
        break;
      case 'disputa':
        c = Colors.amber.shade700;
        label = 'Disputa';
        break;
      default:
        c = _textGrey;
        label = estado;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: c.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8)),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, color: c, fontWeight: FontWeight.w600)),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}
