import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../../services/api_client.dart';

class PagosFinanzasScreen extends StatefulWidget {
  const PagosFinanzasScreen({super.key});

  @override
  State<PagosFinanzasScreen> createState() => _PagosFinanzasScreenState();
}

class _PagosFinanzasScreenState extends State<PagosFinanzasScreen>
    with TickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _loading = true;
  Map<String, dynamic> _data = {};
  List<Map<String, dynamic>> _commissions = [];
  List<Map<String, dynamic>> _pendingPayments = [];
  late AnimationController _animCtrl;
  late Animation<double> _anim;
  String _periodoActivo = 'Mes';

  final List<String> _periodos = ['Semana', 'Mes', 'Trimestre', 'Año'];

  Map<String, String> get _authHeaders => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${ApiClient.instance.token}',
  };

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) setState(() {});
    });
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
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
    setState(() => _loading = true);
    await Future.wait([_fetchEarnings(), _fetchCommissions(), _fetchPendingPayments()]);
    _animCtrl.forward(from: 0);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _fetchEarnings() async {
    try {
      final res = await http.get(
        Uri.parse('${ApiClient.baseUrl}/api/admin/earnings'),
        headers: _authHeaders,
      );
      if (res.statusCode == 200) {
        _data = jsonDecode(res.body);
        return;
      }
    } catch (_) {}
    _data = {
      'totalIngresos': 1393.38,
      'totalTransacciones': 402.00,
      'dolarTransacciones': 252.00,
      'grafica': [0.2, 0.35, 0.3, 0.5, 0.45, 0.6, 0.55, 0.75, 0.7, 0.9, 0.85, 1.0],
      'etiquetas': ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'],
      'pagos': [
        {'tipo': 'Transacciones', 'sub': '15 activas', 'monto': 393.00, 'icon': 'swap'},
        {'tipo': 'Pagos', 'sub': '28 pines', 'monto': 558.00, 'icon': 'payment'},
        {'tipo': 'Pasajeros', 'sub': '', 'monto': 506.00, 'icon': 'person'},
      ],
    };
  }

  Future<void> _fetchCommissions() async {
    try {
      final res = await http.get(
        Uri.parse('${ApiClient.baseUrl}/api/admin/commissions'),
        headers: _authHeaders,
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        _commissions = List<Map<String, dynamic>>.from(body is List ? body : body['data'] ?? body['commissions'] ?? []);
        return;
      }
    } catch (_) {}
    _commissions = [
      {'conductorId': 1, 'nombre': 'Carlos Mendoza', 'monto': 45.50, 'pagada': false},
      {'conductorId': 2, 'nombre': 'Ana López', 'monto': 32.00, 'pagada': false},
      {'conductorId': 3, 'nombre': 'Pedro Ramirez', 'monto': 78.25, 'pagada': true},
      {'conductorId': 4, 'nombre': 'Lucía Fernández', 'monto': 12.80, 'pagada': false},
    ];
  }

  Future<void> _fetchPendingPayments() async {
    try {
      final res = await http.get(
        Uri.parse('${ApiClient.baseUrl}/api/admin/payments/pending'),
        headers: _authHeaders,
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        _pendingPayments = List<Map<String, dynamic>>.from(body is List ? body : body['data'] ?? body['payments'] ?? []);
        return;
      }
    } catch (_) {}
    _pendingPayments = [
      {'userId': 101, 'nombre': 'María García', 'email': 'maria@mail.com', 'monto': 150.00, 'concepto': 'Pago de servicios'},
      {'userId': 102, 'nombre': 'José Martinez', 'email': 'jose@mail.com', 'monto': 220.50, 'concepto': 'Comisión viajes'},
      {'userId': 103, 'nombre': 'Elena Torres', 'email': 'elena@mail.com', 'monto': 89.99, 'concepto': 'Reembolso'},
    ];
  }

  Future<void> _markPaid(int conductorId) async {
    try {
      final res = await http.put(
        Uri.parse('${ApiClient.baseUrl}/api/admin/commissions/$conductorId/paid'),
        headers: _authHeaders,
      );
      if (res.statusCode == 200) {
        await _fetchCommissions();
        if (mounted) setState(() {});
        return;
      }
    } catch (_) {}
    setState(() {
      final idx = _commissions.indexWhere((c) => c['conductorId'] == conductorId);
      if (idx != -1) _commissions[idx]['pagada'] = true;
    });
  }

  Future<void> _confirmPayment(int userId) async {
    try {
      final res = await http.put(
        Uri.parse('${ApiClient.baseUrl}/api/admin/payments/$userId/confirm'),
        headers: _authHeaders,
      );
      if (res.statusCode == 200) {
        await _fetchPendingPayments();
        if (mounted) setState(() {});
        return;
      }
    } catch (_) {}
    setState(() {
      _pendingPayments.removeWhere((p) => p['userId'] == userId);
    });
  }

  Future<void> _rejectPayment(int userId) async {
    try {
      final res = await http.put(
        Uri.parse('${ApiClient.baseUrl}/api/admin/payments/$userId/reject'),
        headers: _authHeaders,
      );
      if (res.statusCode == 200) {
        await _fetchPendingPayments();
        if (mounted) setState(() {});
        return;
      }
    } catch (_) {}
    setState(() {
      _pendingPayments.removeWhere((p) => p['userId'] == userId);
    });
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
                labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
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
                      const Icon(Icons.people_outline, size: 18, color: Colors.black87),
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
                        style: const TextStyle(fontSize: 11, color: Colors.black38),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFF0F0F0)),
                if (_commissions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Sin comisiones pendientes', style: TextStyle(color: Colors.black45)),
                  )
                else
                  ..._commissions.asMap().entries.map((entry) {
                    final i = entry.key;
                    final c = entry.value;
                    final isLast = i == _commissions.length - 1;
                    final pagada = c['pagada'] == true;
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
                                  color: pagada
                                      ? const Color(0xFF4CAF50).withValues(alpha: 0.1)
                                      : const Color(0xFFFB8C00).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  pagada ? Icons.check_circle_outline : Icons.pending_outlined,
                                  color: pagada ? const Color(0xFF4CAF50) : const Color(0xFFFB8C00),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                        color: pagada ? const Color(0xFF4CAF50) : const Color(0xFFFB8C00),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '\$${(c['monto'] as num).toStringAsFixed(2)}',
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
                                    onPressed: () => _markPaid(c['conductorId'] as int),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1E88E5),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
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
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
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
                          const Divider(height: 1, indent: 68, endIndent: 16, color: Color(0xFFF0F0F0)),
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
                      const Icon(Icons.payment_outlined, size: 18, color: Colors.black87),
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
                        style: const TextStyle(fontSize: 11, color: Colors.black38),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFF0F0F0)),
                if (_pendingPayments.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Sin pagos pendientes', style: TextStyle(color: Colors.black45)),
                  )
                else
                  ..._pendingPayments.asMap().entries.map((entry) {
                    final i = entry.key;
                    final p = entry.value;
                    final isLast = i == _pendingPayments.length - 1;
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF8E24AA).withValues(alpha: 0.1),
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
                                      crossAxisAlignment: CrossAxisAlignment.start,
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
                                    '\$${(p['monto'] as num).toStringAsFixed(2)}',
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
                                  padding: const EdgeInsets.only(top: 6, left: 52),
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
                                  SizedBox(
                                    height: 30,
                                    child: OutlinedButton(
                                      onPressed: () => _rejectPayment(p['userId'] as int),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFFE53935),
                                        side: const BorderSide(color: Color(0xFFE53935)),
                                        padding: const EdgeInsets.symmetric(horizontal: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
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
                                      onPressed: () => _confirmPayment(p['userId'] as int),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF4CAF50),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
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
                          const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFF0F0F0)),
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
            icon: const Icon(Icons.chevron_left, color: Colors.black87, size: 26),
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
    final total = _data['totalIngresos'] ?? 0.0;
    final puntos = List<double>.from(_data['grafica'] ?? []);
    final etiquetas = List<String>.from(_data['etiquetas'] ?? []);

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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.trending_up, size: 13, color: Color(0xFF4CAF50)),
                      SizedBox(width: 4),
                      Text(
                        '+12.4%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4CAF50),
                        ),
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
                  onTap: () => setState(() => _periodoActivo = p),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: sel ? Colors.white.withValues(alpha: 0.15) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: sel ? Colors.white30 : Colors.transparent),
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
        'label': 'Total Comisión',
        'valor': '\$${(_data['totalTransacciones'] ?? 0.0).toStringAsFixed(2)}',
        'icon': Icons.account_balance_wallet_outlined,
        'color': const Color(0xFF1E88E5),
      },
      {
        'label': 'USD Transacciones',
        'valor': '\$${(_data['dolarTransacciones'] ?? 0.0).toStringAsFixed(2)}',
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
                left: m == metricas.last ? 7 : 0),
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
                  child: Icon(m['icon'] as IconData,
                      color: m['color'] as Color, size: 18),
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
                            fontWeight: FontWeight.w500),
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
    final pagos = List<Map<String, dynamic>>.from(_data['pagos'] ?? []);
    final total = _data['totalIngresos'] ?? 1.0;

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
                  'Desglose de Pagos',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                Text(
                  '${pagos.length} categorías',
                  style: const TextStyle(fontSize: 11, color: Colors.black38),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          ...pagos.asMap().entries.map((entry) {
            final i = entry.key;
            final p = entry.value;
            final pct = total > 0
                ? (p['monto'] as num) / (total as num)
                : 0.0;
            final isLast = i == pagos.length - 1;
            return _PagoRow(
              tipo: p['tipo'] ?? '',
              sub: p['sub'] ?? '',
              monto: (p['monto'] as num).toDouble(),
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
                      Text(sub,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.black45)),
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
              color: Color(0xFFF0F0F0)),
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
          (offsets[i - 1].dx + offsets[i].dx) / 2, offsets[i - 1].dy);
      final cp2 = Offset(
          (offsets[i - 1].dx + offsets[i].dx) / 2, offsets[i].dy);
      fillPath.cubicTo(
          cp1.dx, cp1.dy, cp2.dx, cp2.dy, offsets[i].dx, offsets[i].dy);
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
        ).createShader(
            Rect.fromLTWH(0, paddingTop, size.width, chartH)),
    );

    final linePath = Path();
    linePath.moveTo(offsets.first.dx, offsets.first.dy);
    for (int i = 1; i < offsets.length; i++) {
      final cp1 = Offset(
          (offsets[i - 1].dx + offsets[i].dx) / 2, offsets[i - 1].dy);
      final cp2 = Offset(
          (offsets[i - 1].dx + offsets[i].dx) / 2, offsets[i].dy);
      linePath.cubicTo(
          cp1.dx, cp1.dy, cp2.dx, cp2.dy, offsets[i].dx, offsets[i].dy);
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
      canvas.drawCircle(
        offsets.last,
        4,
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(
        offsets.last,
        2,
        Paint()..color = const Color(0xFF1A1A2E),
      );
    }

    final labelStyle = const TextStyle(
        fontSize: 9.5,
        color: Colors.white38,
        fontWeight: FontWeight.w500);
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
          Offset(x - tp.width / 2,
              size.height - paddingBottom + 6));
    }
  }

  @override
  bool shouldRepaint(_AreaChartPainter old) =>
      old.progress != progress || old.points != points;
}
