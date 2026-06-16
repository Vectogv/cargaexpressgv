import 'package:flutter/material.dart';
import '../../services/api_client.dart';

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  Map<String, dynamic>? _earnings;
  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _commission;
  bool _loading = true;

  static const Color _primaryDark = Color(0xFF1A3C6E);
  static const Color _textGrey = Color(0xFF757575);
  static const Color _bgLight = Color(0xFFF5F7FA);
  static const Color _white = Colors.white;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        ApiClient.instance.getEarnings(),
        ApiClient.instance.getDriverStats(),
        ApiClient.instance.getDebt(),
      ]);
      if (mounted) setState(() {
        _earnings = results[0];
        _stats = results[1];
        _commission = results[2];
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildPeriodRow(),
                        const SizedBox(height: 12),
                        _buildStatsRow(),
                        const SizedBox(height: 12),
                        _buildCommissionCard(),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: _white,
      padding: const EdgeInsets.only(top: 44, left: 16, right: 16, bottom: 14),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back_ios_new, size: 20),
          ),
          const SizedBox(width: 12),
          const Text(
            'Ganancias',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  num _toNum(dynamic v) {
    if (v is num) return v;
    if (v is Map) return (v['amount'] ?? v['monto'] ?? 0) as num;
    return 0;
  }

  Widget _buildPeriodRow() {
    return Row(
      children: [
        Expanded(child: _buildPeriodCard('Hoy', _toNum(_earnings?['hoy']))),
        const SizedBox(width: 8),
        Expanded(child: _buildPeriodCard('Semana', _toNum(_earnings?['semana']))),
        const SizedBox(width: 8),
        Expanded(child: _buildPeriodCard('Mes', _toNum(_earnings?['mes']))),
      ],
    );
  }

  Widget _buildPeriodCard(String label, num amount) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Text('\$${_formatAmount(amount)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _primaryDark)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, color: _textGrey, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final viajes = _toNum(_stats?['viajes']);
    final calificacion = _toNum(_stats?['calificacion']);
    final total = _toNum(_earnings?['total']);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statItem(Icons.route_outlined, '$viajes', 'Viajes\ncompletados'),
              _statItem(Icons.star_rounded, calificacion.toStringAsFixed(1), 'Calificación'),
              _statItem(Icons.monetization_on_outlined, '\$${_formatAmount(total)}', 'Total\nacumulado'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: _primaryDark, size: 22),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 9, color: _textGrey), textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildCommissionCard() {
    final pendiente = _toNum(_commission?['monto'] ?? _commission?['deuda']);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.account_balance_wallet_outlined, color: Colors.red.shade700, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(      child: Text('Deuda pendiente', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
          Text('\$${_formatAmount(pendiente)}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.red.shade700)),
        ],
      ),
    );
  }

  String _formatAmount(num amount) {
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(amount % 1000 == 0 ? 0 : 1)}k';
    }
    return amount.toStringAsFixed(amount == amount.roundToDouble() ? 0 : 2);
  }
}
