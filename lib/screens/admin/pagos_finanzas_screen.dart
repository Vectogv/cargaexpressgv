import 'package:flutter/material.dart';
import 'dart:math';
import '../../services/api/http_client.dart';
import 'admin_common.dart';

/// Montos: el backend puede serializar decimales como texto.
num _num(dynamic v) => v is num ? v : num.tryParse('${v ?? ''}') ?? 0;

String _fmtDate(dynamic iso) {
  final dt = DateTime.tryParse(iso?.toString() ?? '')?.toLocal();
  if (dt == null) return '';
  return '${dt.day}/${dt.month}/${dt.year}';
}

class PagosFinanzasScreen extends StatefulWidget {
  const PagosFinanzasScreen({super.key});

  @override
  State<PagosFinanzasScreen> createState() => _PagosFinanzasScreenState();
}

class _PagosFinanzasScreenState extends State<PagosFinanzasScreen>
    with TickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _loading = true;
  bool _hasError = false;
  String? _errorMsg;
  /// Resumen calculado a partir de GET /api/admin/earnings (lista de
  /// ganancias {monto, conductor{nombre,apellido,placa}, createdAt}).
  Map<String, dynamic> _data = {};
  List<Map<String, dynamic>> _earnings = [];
  List<Map<String, dynamic>> _commissions = [];
  List<Map<String, dynamic>> _pendingPayments = [];
  late AnimationController _animCtrl;
  late Animation<double> _anim;
  String _periodoActivo = 'Mes';

  final List<String> _periodos = ['Semana', 'Mes', 'Trimestre', 'Año'];

  @override
  void initState() {
    super.initState();
    // Sin listener de pestaña: TabBarView gestiona su propio estado y un
    // setState por cambio de pestaña reconstruía toda la pantalla.
    _tabCtrl = TabController(length: 3, vsync: this);
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _anim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
    _fetchAll();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchAll() async {
    setState(() {
      _loading = true;
      _hasError = false;
      _errorMsg = null;
    });
    await Future.wait([
      _fetchEarnings(),
      _fetchCommissions(),
      _fetchPendingPayments(),
    ]);
    if (!mounted) return;
    _animCtrl.forward(from: 0);
    setState(() => _loading = false);
  }

  void _fail(Object e) {
    _hasError = true;
    _errorMsg ??= adminErrorText(e);
  }

  Future<void> _fetchEarnings() async {
    try {
      final data = await HttpClient.getList('/api/admin/earnings?limit=100', auth: true);
      _earnings = adminMapList(data);
      _data = _buildSummary();
    } catch (e) {
      _fail(e);
      _earnings = [];
      _data = {};
    }
  }

  Future<void> _fetchCommissions() async {
    try {
      final data = await HttpClient.getList('/api/admin/commissions', auth: true);
      if (!mounted) return;
      // setState: también se usa como onRefresh de la pestaña.
      setState(() {
        _commissions = adminMapList(data);
        _data = _buildSummary();
      });
    } catch (e) {
      if (!mounted) return;
      if (_loading) {
        _fail(e);
      } else {
        _showCommissionError(adminErrorText(e));
      }
    }
  }

  Future<void> _fetchPendingPayments() async {
    try {
      final data = await HttpClient.getList('/api/admin/payments/pending', auth: true);
      if (!mounted) return;
      setState(() => _pendingPayments = adminMapList(data));
    } catch (e) {
      if (!mounted) return;
      if (_loading) {
        _fail(e);
      } else {
        _showCommissionError(adminErrorText(e));
      }
    }
  }

  static const _periodoDias = {'Semana': 7, 'Mes': 30, 'Trimestre': 90, 'Año': 365};

  /// Resumen del periodo activo: total, variación contra el periodo anterior,
  /// serie para la gráfica (6 tramos) y los conductores con más ingresos.
  Map<String, dynamic> _buildSummary() {
    final dias = _periodoDias[_periodoActivo] ?? 30;
    final now = DateTime.now();
    final desde = now.subtract(Duration(days: dias));
    final previo = desde.subtract(Duration(days: dias));
    const tramos = 6;
    final serie = List<double>.filled(tramos, 0);
    double total = 0, totalPrevio = 0;
    int transacciones = 0;
    final porConductor = <String, Map<String, dynamic>>{};

    for (final g in _earnings) {
      final fecha = DateTime.tryParse(g['createdAt']?.toString() ?? '')?.toLocal();
      if (fecha == null) continue;
      final monto = _num(g['monto']).toDouble();
      if (fecha.isBefore(desde)) {
        if (!fecha.isBefore(previo)) totalPrevio += monto;
        continue;
      }
      total += monto;
      transacciones++;
      final idx = ((fecha.difference(desde).inMinutes / (dias * 24 * 60)) * tramos)
          .floor()
          .clamp(0, tramos - 1);
      serie[idx] += monto;
      final c = g['conductor'] is Map ? g['conductor'] as Map : const {};
      final key = g['conductorId']?.toString() ?? '-';
      final entry = porConductor.putIfAbsent(key, () => {
            'tipo': '${c['nombre'] ?? ''} ${c['apellido'] ?? ''}'.trim().isEmpty
                ? 'Conductor #$key'
                : '${c['nombre'] ?? ''} ${c['apellido'] ?? ''}'.trim(),
            'placa': c['placa']?.toString() ?? '',
            'monto': 0.0,
            'viajes': 0,
          });
      entry['monto'] = (entry['monto'] as double) + monto;
      entry['viajes'] = (entry['viajes'] as int) + 1;
    }

    final maxSerie = serie.fold<double>(0, max);
    final pagos = porConductor.values.toList()
      ..sort((a, b) => (b['monto'] as double).compareTo(a['monto'] as double));
    final etiquetas = List<String>.generate(tramos, (i) {
      final d = desde.add(Duration(minutes: (dias * 24 * 60 * i / tramos).round()));
      return '${d.day}/${d.month}';
    });

    return {
      'totalIngresos': total,
      'variacion': totalPrevio > 0 ? (total - totalPrevio) / totalPrevio * 100 : null,
      // La gráfica espera valores normalizados 0..1.
      'grafica': maxSerie > 0 ? serie.map((v) => v / maxSerie).toList() : serie,
      'etiquetas': etiquetas,
      'totalTransacciones': _commissions.fold<num>(0, (s, c) => s + _num(c['comisionPendiente'] ?? c['monto'])),
      'transacciones': transacciones,
      'pagos': pagos
          .take(6)
          .map((p) => {
                'tipo': p['tipo'],
                'sub': '${p['placa']} · ${p['viajes']} viaje${p['viajes'] == 1 ? '' : 's'}',
                'monto': p['monto'],
                'icon': 'person',
              })
          .toList(),
    };
  }

  Future<void> _markPaid(int conductorId) async {
    try {
      await HttpClient.put('/api/admin/commissions/$conductorId/paid', auth: true);
      await _fetchCommissions();
    } catch (e) {
      _showCommissionError(adminErrorText(e));
    }
  }

  Future<void> _showCommissionHistory(int conductorId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final history = await HttpClient.getList('/api/admin/commissions/$conductorId/history', auth: true);
      if (!mounted) return;
      Navigator.of(context).pop();
      _showHistoryDialog(conductorId, history);
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      _showCommissionError(adminErrorText(e));
    }
  }

  void _showHistoryDialog(int conductorId, List history) {
    final conductor = _commissions.firstWhere(
      (c) => c['conductorId'] == conductorId,
      orElse: () => {'nombre': 'Conductor'},
    );
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Historial - ${conductor['nombre']}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              if (history.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Sin historial disponible',
                    style: TextStyle(color: Colors.black45),
                  ),
                )
              else
                // Backend: {viajeId, montoBruto, comision, montoNeto, pagada,
                // pagadaAt, viaje{origen,destino}, createdAt}
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: history.length,
                    itemBuilder: (_, i) {
                      final h = history[i];
                      final pagadaH = h['pagada'] == true;
                      final comision = _num(h['comision']);
                      return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Viaje #${h['viajeId'] ?? ''} · ${pagadaH ? 'Pagada' : 'Pendiente'}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              Text(
                                '${_fmtDate(h['createdAt'])} · bruto \$${_num(h['montoBruto']).toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.black45,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '\$${comision.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: pagadaH ? const Color(0xFF4CAF50) : const Color(0xFFE53935),
                          ),
                        ),
                      ],
                    ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cerrar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCommissionError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _confirmPayment(int userId) async {
    try {
      final res = await HttpClient.put('/api/admin/payments/$userId/confirm', auth: true);
      adminSnack(this, res['message']?.toString() ?? 'Pago confirmado', color: const Color(0xFF4CAF50));
      await _fetchPendingPayments();
    } catch (e) {
      _showCommissionError(adminErrorText(e));
    }
  }

  Future<void> _rejectPayment(int userId) async {
    try {
      final res = await HttpClient.put('/api/admin/payments/$userId/reject', auth: true);
      adminSnack(this, res['message']?.toString() ?? 'Pago rechazado');
      await _fetchPendingPayments();
    } catch (e) {
      _showCommissionError(adminErrorText(e));
    }
  }

  /// El comprobante es una URL relativa firmada (válida 1 h): se resuelve
  /// con resolveMediaUrl y se muestra con placeholder si falla (p. ej. PDF).
  void _showComprobante(Map<String, dynamic> p) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Comprobante - ${p['nombre'] ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AdminDocImage(p['comprobante']?.toString(), height: 360, width: double.infinity, fit: BoxFit.contain),
              ),
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F7),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabCtrl,
                indicatorColor: Colors.black87,
                labelColor: Colors.black87,
                unselectedLabelColor: Colors.black38,
                labelStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
                tabs: const [
                  Tab(text: 'Dashboard'),
                  Tab(text: 'Comisiones'),
                  Tab(text: 'Pagos'),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _hasError && _earnings.isEmpty && _commissions.isEmpty && _pendingPayments.isEmpty
                      ? _buildErrorState()
                      : TabBarView(
                          controller: _tabCtrl,
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            _buildDashboardTab(),
                            _buildComisionesTab(),
                            _buildPagosTab(),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 56, color: Colors.black26),
            const SizedBox(height: 16),
            const Text(
              'No se pudieron cargar los datos financieros',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMsg ?? 'Verifica tu conexión e intenta nuevamente.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.black38),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _fetchAll,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A3C6E),
                foregroundColor: Colors.white,
              ),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardTab() {
    return RefreshIndicator(
      onRefresh: _fetchAll,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeroCard(),
            const SizedBox(height: 14),
            _buildMetricas(),
            const SizedBox(height: 14),
            _buildPaymentsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildComisionesTab() {
    return RefreshIndicator(
      onRefresh: _fetchCommissions,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.people_outline,
                        size: 18,
                        color: Colors.black87,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Comisiones / Deudas',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_commissions.length} conductores',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black38,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFF0F0F0)),
                if (_commissions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Sin comisiones pendientes',
                      style: TextStyle(color: Colors.black45),
                    ),
                  )
                else
                  ..._commissions.asMap().entries.map((entry) {
                    final i = entry.key;
                    final c = entry.value;
                    final isLast = i == _commissions.length - 1;
                    final pagada = c['pagada'] == true;
                    return GestureDetector(
                      onTap: () =>
                          _showCommissionHistory(c['conductorId'] as int),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: pagada
                                        ? const Color(
                                            0xFF4CAF50,
                                          ).withValues(alpha: 0.1)
                                        : const Color(
                                            0xFFFB8C00,
                                          ).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    pagada
                                        ? Icons.check_circle_outline
                                        : Icons.pending_outlined,
                                    color: pagada
                                        ? const Color(0xFF4CAF50)
                                        : const Color(0xFFFB8C00),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        c['nombre'] ?? 'Sin nombre',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      Text(
                                        pagada ? 'Pagada' : 'Pendiente',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: pagada
                                              ? const Color(0xFF4CAF50)
                                              : const Color(0xFFFB8C00),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '\$${_num(c['monto']).toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                if (!pagada)
                                  SizedBox(
                                    height: 30,
                                    child: ElevatedButton(
                                      onPressed: () =>
                                          _markPaid(c['conductorId'] as int),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF1E88E5,
                                        ),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        textStyle: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      child: const Text('Pagar'),
                                    ),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF4CAF50,
                                      ).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'Pagado',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF4CAF50),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (!isLast)
                            const Divider(
                              height: 1,
                              indent: 68,
                              endIndent: 16,
                              color: Color(0xFFF0F0F0),
                            ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPagosTab() {
    return RefreshIndicator(
      onRefresh: _fetchPendingPayments,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.payment_outlined,
                        size: 18,
                        color: Colors.black87,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Pagos Pendientes',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_pendingPayments.length} pendientes',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black38,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFF0F0F0)),
                if (_pendingPayments.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Sin pagos pendientes',
                      style: TextStyle(color: Colors.black45),
                    ),
                  )
                else
                  ..._pendingPayments.asMap().entries.map((entry) {
                    final i = entry.key;
                    final p = entry.value;
                    final isLast = i == _pendingPayments.length - 1;
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF8E24AA,
                                      ).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.person_outline,
                                      color: Color(0xFF8E24AA),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p['nombre'] ?? 'Sin nombre',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        if (p['email'] != null)
                                          Text(
                                            p['email'],
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.black45,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '\$${_num(p['monto']).toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                              if (p['concepto'] != null)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 6,
                                    left: 52,
                                  ),
                                  child: Text(
                                    p['concepto'],
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.black45,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (p['comprobante'] != null)
                                    TextButton.icon(
                                      onPressed: () => _showComprobante(p),
                                      icon: const Icon(Icons.receipt_long_outlined, size: 16),
                                      label: const Text('Comprobante', style: TextStyle(fontSize: 11)),
                                    ),
                                  const Spacer(),
                                  SizedBox(
                                    height: 30,
                                    child: OutlinedButton(
                                      onPressed: () =>
                                          _rejectPayment(p['userId'] as int),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(
                                          0xFFE53935,
                                        ),
                                        side: const BorderSide(
                                          color: Color(0xFFE53935),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        textStyle: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      child: const Text('Rechazar'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    height: 30,
                                    child: ElevatedButton(
                                      onPressed: () =>
                                          _confirmPayment(p['userId'] as int),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF4CAF50,
                                        ),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        textStyle: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      child: const Text('Confirmar'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (!isLast)
                          const Divider(
                            height: 1,
                            indent: 16,
                            endIndent: 16,
                            color: Color(0xFFF0F0F0),
                          ),
                      ],
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      color: const Color(0xFFF2F3F7),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.chevron_left,
              color: Colors.black87,
              size: 26,
            ),
            onPressed: () => Navigator.maybePop(context),
          ),
          const Text(
            'PAGOS Y FINANZAS',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
              letterSpacing: 0.3,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black45, size: 20),
            onPressed: _fetchAll,
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard() {
    final total = _num(_data['totalIngresos']).toDouble();
    final puntos = List<double>.from(_data['grafica'] ?? const <double>[]);
    final etiquetas = List<String>.from(_data['etiquetas'] ?? const <String>[]);
    final variacion = _data['variacion'] as double?;
    final sube = (variacion ?? 0) >= 0;
    final varColor = sube ? const Color(0xFF4CAF50) : const Color(0xFFE53935);

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A1A2E).withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Ingresos',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white54,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    AnimatedBuilder(
                      animation: _anim,
                      builder: (_, _) => Text(
                        '\$${(total * _anim.value).toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // Variación real contra el periodo anterior (antes era fija).
                if (variacion != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: varColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: varColor.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        Icon(sube ? Icons.trending_up : Icons.trending_down, size: 13, color: varColor),
                        const SizedBox(width: 4),
                        Text(
                          '${sube ? '+' : ''}${variacion.toStringAsFixed(1)}%',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: varColor),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: _periodos.map((p) {
                final sel = _periodoActivo == p;
                return GestureDetector(
                  onTap: () => setState(() {
                    _periodoActivo = p;
                    _data = _buildSummary();
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: sel
                          ? Colors.white.withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: sel ? Colors.white30 : Colors.transparent,
                      ),
                    ),
                    child: Text(
                      p,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: sel ? Colors.white : Colors.white38,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SizedBox(
              height: 130,
              child: AnimatedBuilder(
                animation: _anim,
                builder: (_, _) => CustomPaint(
                  painter: _AreaChartPainter(
                    points: puntos,
                    labels: etiquetas,
                    progress: _anim.value,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricas() {
    final metricas = [
      {
        'label': 'Comisión pendiente',
        'valor': '\$${_num(_data['totalTransacciones']).toStringAsFixed(2)}',
        'icon': Icons.account_balance_wallet_outlined,
        'color': const Color(0xFF1E88E5),
      },
      {
        'label': 'Transacciones',
        'valor': '${_data['transacciones'] ?? 0}',
        'icon': Icons.attach_money_rounded,
        'color': const Color(0xFF43A047),
      },
    ];

    return Row(
      children: metricas.map((m) {
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(
              right: m == metricas.first ? 7 : 0,
              left: m == metricas.last ? 7 : 0,
            ),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: (m['color'] as Color).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    m['icon'] as IconData,
                    color: m['color'] as Color,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m['label'] as String,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.black45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        m['valor'] as String,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPaymentsList() {
    final pagos = List<Map<String, dynamic>>.from(_data['pagos'] ?? const <Map<String, dynamic>>[]);
    final total = _num(_data['totalIngresos']);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Text(
                  'Ingresos por conductor',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                Text(
                  '${pagos.length} conductores',
                  style: const TextStyle(fontSize: 11, color: Colors.black38),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          ...pagos.asMap().entries.map((entry) {
            final i = entry.key;
            final p = entry.value;
            final pct = total > 0 ? _num(p['monto']) / total : 0.0;
            final isLast = i == pagos.length - 1;
            return _PagoRow(
              tipo: p['tipo'] ?? '',
              sub: p['sub'] ?? '',
              monto: _num(p['monto']).toDouble(),
              icon: p['icon'] ?? 'swap',
              porcentaje: pct.clamp(0.0, 1.0),
              isLast: isLast,
              animacion: _anim,
            );
          }),
        ],
      ),
    );
  }
}

class _PagoRow extends StatelessWidget {
  final String tipo;
  final String sub;
  final double monto;
  final String icon;
  final double porcentaje;
  final bool isLast;
  final Animation<double> animacion;

  const _PagoRow({
    required this.tipo,
    required this.sub,
    required this.monto,
    required this.icon,
    required this.porcentaje,
    required this.isLast,
    required this.animacion,
  });

  IconData get _icon {
    switch (icon) {
      case 'payment':
        return Icons.credit_card_rounded;
      case 'person':
        return Icons.people_alt_rounded;
      default:
        return Icons.swap_horiz_rounded;
    }
  }

  Color get _color {
    switch (icon) {
      case 'payment':
        return const Color(0xFFFB8C00);
      case 'person':
        return const Color(0xFF8E24AA);
      default:
        return const Color(0xFF1E88E5);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_icon, color: _color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tipo,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    if (sub.isNotEmpty)
                      Text(
                        sub,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black45,
                        ),
                      ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: AnimatedBuilder(
                        animation: animacion,
                        builder: (_, _) => LinearProgressIndicator(
                          value: porcentaje * animacion.value,
                          minHeight: 4,
                          backgroundColor: const Color(0xFFF0F0F0),
                          valueColor: AlwaysStoppedAnimation<Color>(_color),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${monto.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    '${(porcentaje * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _color,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (!isLast)
          const Divider(
            height: 1,
            indent: 68,
            endIndent: 16,
            color: Color(0xFFF0F0F0),
          ),
      ],
    );
  }
}

class _AreaChartPainter extends CustomPainter {
  final List<double> points;
  final List<String> labels;
  final double progress;

  const _AreaChartPainter({
    required this.points,
    required this.labels,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final paddingLeft = 16.0;
    final paddingRight = 16.0;
    final paddingTop = 10.0;
    final paddingBottom = 24.0;

    final chartW = size.width - paddingLeft - paddingRight;
    final chartH = size.height - paddingTop - paddingBottom;

    final visibleCount = max(2, (points.length * progress).round());
    final visiblePoints = points.sublist(0, min(visibleCount, points.length));

    List<Offset> offsets = [];
    for (int i = 0; i < visiblePoints.length; i++) {
      final x = paddingLeft + (i / (points.length - 1)) * chartW;
      final y = paddingTop + chartH * (1 - visiblePoints[i]);
      offsets.add(Offset(x, y));
    }

    if (offsets.length < 2) return;

    final fillPath = Path();
    fillPath.moveTo(offsets.first.dx, paddingTop + chartH);
    fillPath.lineTo(offsets.first.dx, offsets.first.dy);
    for (int i = 1; i < offsets.length; i++) {
      final cp1 = Offset(
        (offsets[i - 1].dx + offsets[i].dx) / 2,
        offsets[i - 1].dy,
      );
      final cp2 = Offset(
        (offsets[i - 1].dx + offsets[i].dx) / 2,
        offsets[i].dy,
      );
      fillPath.cubicTo(
        cp1.dx,
        cp1.dy,
        cp2.dx,
        cp2.dy,
        offsets[i].dx,
        offsets[i].dy,
      );
    }
    fillPath.lineTo(offsets.last.dx, paddingTop + chartH);
    fillPath.close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.25),
            Colors.white.withValues(alpha: 0.02),
          ],
        ).createShader(Rect.fromLTWH(0, paddingTop, size.width, chartH)),
    );

    final linePath = Path();
    linePath.moveTo(offsets.first.dx, offsets.first.dy);
    for (int i = 1; i < offsets.length; i++) {
      final cp1 = Offset(
        (offsets[i - 1].dx + offsets[i].dx) / 2,
        offsets[i - 1].dy,
      );
      final cp2 = Offset(
        (offsets[i - 1].dx + offsets[i].dx) / 2,
        offsets[i].dy,
      );
      linePath.cubicTo(
        cp1.dx,
        cp1.dy,
        cp2.dx,
        cp2.dy,
        offsets[i].dx,
        offsets[i].dy,
      );
    }

    canvas.drawPath(
      linePath,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    if (offsets.isNotEmpty) {
      canvas.drawCircle(offsets.last, 4, Paint()..color = Colors.white);
      canvas.drawCircle(
        offsets.last,
        2,
        Paint()..color = const Color(0xFF1A1A2E),
      );
    }

    final labelStyle = const TextStyle(
      fontSize: 9.5,
      color: Colors.white38,
      fontWeight: FontWeight.w500,
    );
    final step = max(1, (labels.length / 6).round());
    for (int i = 0; i < labels.length; i += step) {
      if (i >= points.length) break;
      final x = paddingLeft + (i / (points.length - 1)) * chartW;
      final tp = TextPainter(
        text: TextSpan(text: labels[i], style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(x - tp.width / 2, size.height - paddingBottom + 6),
      );
    }
  }

  @override
  bool shouldRepaint(_AreaChartPainter old) =>
      old.progress != progress || old.points != points;
}
