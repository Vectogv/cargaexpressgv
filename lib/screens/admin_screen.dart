import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../services/admin_service.dart';
import '../services/api_client.dart';

class _AdminNotification {
  final String id;
  final String tipo;
  final String mensaje;
  final DateTime createdAt;
  bool leido;

  _AdminNotification({
    required this.id,
    required this.tipo,
    required this.mensaje,
    required this.createdAt,
    this.leido = false,
  });
}

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with TickerProviderStateMixin {
  final _service = AdminService();
  int _tab = 0;
  final List<_AdminNotification> _notificaciones = [];
  List<Map<String, dynamic>> _pendingPayments = [];
  io.Socket? _socket;
  late AnimationController _pulseCtrl;

  String get _socketServerUrl {
    final base = ApiClient().baseUrl;
    if (base.endsWith('/api')) {
      return base.substring(0, base.length - 4);
    }
    return base;
  }

  int get _unreadCount => _notificaciones.where((n) => !n.leido).length;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _conectarSocket();
  }

  void _conectarSocket() {
    _socket?.disconnect();
    _socket?.dispose();

    _socket = io.io(_socketServerUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    _socket!.connect();

    _socket!.onConnect((_) {
      _socket!.emit('join:admin', 'admin');
    });

    _socket!.on('emergency:new', (data) {
      if (!mounted) return;
      final notif = _AdminNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        tipo: 'emergency',
        mensaje: data is Map ? data['mensaje'] ?? 'Emergencia reportada' : 'Emergencia reportada',
        createdAt: DateTime.now(),
      );
      setState(() => _notificaciones.insert(0, notif));
    });

    _socket!.on('trip:new', (data) {
      if (!mounted) return;
      final notif = _AdminNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        tipo: 'trip',
        mensaje: data is Map ? 'Nuevo viaje: ${data['origen'] ?? ''} → ${data['destino'] ?? ''}' : 'Nuevo viaje solicitado',
        createdAt: DateTime.now(),
      );
      setState(() => _notificaciones.insert(0, notif));
    });

    _socket!.on('driver:new', (data) {
      if (!mounted) return;
      final notif = _AdminNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        tipo: 'driver',
        mensaje: data is Map ? 'Nuevo conductor: ${data['nombre'] ?? ''}' : 'Nuevo conductor registrado',
        createdAt: DateTime.now(),
      );
      setState(() => _notificaciones.insert(0, notif));
    });

    _socket!.on('admin:payment_proof', (data) {
      if (!mounted) return;
      final pago = data is Map ? data as Map<String, dynamic> : <String, dynamic>{};
      setState(() {
        _pendingPayments.insert(0, pago);
        _notificaciones.insert(0, _AdminNotification(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          tipo: 'payment',
          mensaje: 'Nuevo comprobante de pago de ${pago['clienteNombre'] ?? 'cliente'}',
          createdAt: DateTime.now(),
        ));
      });
    });
  }

  void _showNotificationsPanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.6,
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                    child: Row(
                      children: [
                        const Text('Notificaciones',
                            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        if (_unreadCount > 0)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                for (final n in _notificaciones) {
                                  n.leido = true;
                                }
                              });
                              setModalState(() {});
                            },
                            child: const Text('Marcar todas leídas',
                                style: TextStyle(color: Color(0xFF1A8CFF), fontSize: 13)),
                          ),
                      ],
                    ),
                  ),
                  if (_notificaciones.isEmpty)
                    Expanded(
                      child: Center(
                        child: Text('Sin notificaciones',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 14)),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: _notificaciones.length,
                        itemBuilder: (_, i) {
                          final n = _notificaciones[i];
                          final isEmergency = n.tipo == 'emergency';
                          return GestureDetector(
                            onTap: () {
                              setState(() => n.leido = true);
                              setModalState(() {});
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isEmergency
                                    ? Colors.red.withValues(alpha: n.leido ? 0.08 : 0.15)
                                    : Colors.white.withValues(alpha: n.leido ? 0.03 : 0.06),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isEmergency
                                      ? Colors.redAccent.withValues(alpha: n.leido ? 0.2 : 0.5)
                                      : Colors.white.withValues(alpha: n.leido ? 0.03 : 0.06),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isEmergency
                                          ? Colors.red.withValues(alpha: 0.2)
                                          : const Color(0xFF1A8CFF).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      isEmergency ? Icons.warning_amber_rounded : Icons.notifications_rounded,
                                      size: 20,
                                      color: isEmergency ? Colors.redAccent : const Color(0xFF1A8CFF),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          n.mensaje,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: n.leido ? FontWeight.w400 : FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _formatTime(n.createdAt),
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.3),
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isEmergency && !n.leido)
                                    Container(
                                      width: 8, height: 8,
                                      decoration: const BoxDecoration(
                                        color: Colors.redAccent,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours}h';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _socket?.disconnect();
    _socket?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Panel Admin',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          Stack(
            children: [
              IconButton(
                icon: Icon(Icons.notifications_outlined, color: Colors.white.withValues(alpha: 0.7)),
                onPressed: _showNotificationsPanel,
              ),
              if (_unreadCount > 0)
                Positioned(
                  right: 6, top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$_unreadCount',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.person, color: Colors.white.withValues(alpha: 0.7)),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _AdminProfileScreen())),
          ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          const _DashboardTab(),
          const _UsersTab(),
          const _DriversTab(),
          const _TripsTab(),
          const _EarningsTab(),
          _PaymentsTab(payments: _pendingPayments, onChanged: _refreshPayments),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF0D0D0D),
        selectedItemColor: const Color(0xFF1A8CFF),
        unselectedItemColor: Colors.white38,
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(icon: _buildNavIcon(Icons.dashboard, 0), label: 'Dashboard'),
          const BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Usuarios'),
          const BottomNavigationBarItem(icon: Icon(Icons.local_shipping), label: 'Conductores'),
          const BottomNavigationBarItem(icon: Icon(Icons.route), label: 'Viajes'),
          const BottomNavigationBarItem(icon: Icon(Icons.monetization_on), label: 'Ganancias'),
          BottomNavigationBarItem(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.payment),
                if (_pendingPayments.isNotEmpty)
                  Positioned(
                    right: -6, top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                      child: Text('${_pendingPayments.length}',
                          style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
            label: 'Pagos',
          ),
        ],
      ),
    );
  }

  void _refreshPayments() {
    _service.getPendingPayments().then((res) {
      final apiPayments = (res['payments'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ?? [];
      if (mounted) setState(() => _pendingPayments = apiPayments);
    }).catchError((_) {
      if (mounted) setState(() {});
    });
  }

  Widget _buildNavIcon(IconData icon, int index) {
    if (index == 0 && _unreadCount > 0) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon),
          Positioned(
            right: -8, top: -4,
            child: AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, child) => Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.6 + _pulseCtrl.value * 0.4),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$_unreadCount',
                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      );
    }
    return Icon(icon);
  }
}

// ─── ADMIN PROFILE SCREEN ──────────────────────────────────────────────

class _AdminProfileScreen extends StatefulWidget {
  const _AdminProfileScreen();
  @override
  State<_AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<_AdminProfileScreen> {
  final _service = AdminService();
  final _nombreCtrl = TextEditingController();
  final _apellidoCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _nequiNumeroCtrl = TextEditingController();
  final _nequiTitularCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _avatar;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _emailCtrl.dispose();
    _telefonoCtrl.dispose();
    _nequiNumeroCtrl.dispose();
    _nequiTitularCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final p = await _service.getProfile();
      final nequi = await _service.get('/admin/payments/nequi-config');
      if (mounted) setState(() {
        _nombreCtrl.text = p['nombre'] ?? '';
        _apellidoCtrl.text = p['apellido'] ?? '';
        _emailCtrl.text = p['email'] ?? '';
        _telefonoCtrl.text = p['telefono'] ?? '';
        _avatar = p['avatar'];
        _nequiNumeroCtrl.text = nequi['numero'] ?? '';
        _nequiTitularCtrl.text = nequi['titular'] ?? '';
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    try {
      final res = await _service.uploadProfileAvatar(bytes, file.name);
      if (mounted) setState(() => _avatar = res['avatar']);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _service.updateProfile({
        'nombre': _nombreCtrl.text,
        'apellido': _apellidoCtrl.text,
        'email': _emailCtrl.text,
        'telefono': _telefonoCtrl.text,
      });
      await _service.saveNequiConfig(_nequiNumeroCtrl.text, _nequiTitularCtrl.text);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil actualizado'), backgroundColor: Color(0xFF1A8CFF)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: const Text('Mi Perfil', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1A8CFF)))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                GestureDetector(
                  onTap: _pickAvatar,
                  child: Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 48,
                          backgroundColor: const Color(0xFF1A8CFF).withValues(alpha: 0.15),
                          backgroundImage: _avatar != null ? NetworkImage('${ApiClient.defaultBaseUrl.replaceAll('/api', '')}$_avatar') : null,
                          child: _avatar == null
                              ? const Icon(Icons.admin_panel_settings, color: Color(0xFF1A8CFF), size: 40)
                              : null,
                        ),
                        Positioned(
                          bottom: 0, right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A8CFF), shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                _field('Nombre', _nombreCtrl),
                const SizedBox(height: 16),
                _field('Apellido', _apellidoCtrl),
                const SizedBox(height: 16),
                _field('Email', _emailCtrl, keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 16),
                _field('Teléfono', _telefonoCtrl, keyboardType: TextInputType.phone),
                const SizedBox(height: 32),
                const Text('CONFIGURACIÓN DE PAGOS',
                    style: TextStyle(color: Color(0xFF1A8CFF), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                const SizedBox(height: 16),
                _field('Número Nequi', _nequiNumeroCtrl, keyboardType: TextInputType.phone),
                const SizedBox(height: 16),
                _field('Nombre titular Nequi', _nequiTitularCtrl),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A8CFF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _saving
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Guardar cambios', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.06),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
}

// ─── DASHBOARD ─────────────────────────────────────────────────────────

class _DashboardTab extends StatefulWidget {
  const _DashboardTab();
  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  final _service = AdminService();
  AdminDashboard? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _service.getDashboard();
      if (mounted) setState(() { _data = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: Color(0xFF1A8CFF)));
    if (_data == null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.error_outline, size: 48, color: Colors.white.withValues(alpha: 0.2)),
        const SizedBox(height: 16),
        Text('Error al cargar', style: TextStyle(color: Colors.white.withValues(alpha: 0.4))),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: () { setState(() => _loading = true); _load(); }, child: const Text('Reintentar')),
      ]));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        _header(),
        const SizedBox(height: 20),
        _earningsCard(),
        const SizedBox(height: 16),
        _statsGrid(),
        const SizedBox(height: 16),
        _summaryCard(),
      ]),
    );
  }

  Widget _header() => Column(children: [
    Container(width: 64, height: 64, decoration: BoxDecoration(
      color: const Color(0xFF1A8CFF).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(18)),
      child: const Icon(Icons.admin_panel_settings, color: Color(0xFF1A8CFF), size: 32)),
    const SizedBox(height: 12),
    const Text('Dashboard', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
    Text('Panel de administración', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13)),
  ]);

  Widget _earningsCard() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [const Color(0xFF1A8CFF).withValues(alpha: 0.2), const Color(0xFF0A0A0A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFF1A8CFF).withValues(alpha: 0.2))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(Icons.monetization_on, size: 18, color: Colors.greenAccent), const SizedBox(width: 8),
        const Text('GANANCIAS', style: TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5))]),
      const SizedBox(height: 20),
      Row(children: [
        _earningItem('Hoy', '\$${_data!.todayEarnings.toStringAsFixed(2)}'),
        _earningItem('Este mes', '\$${_data!.monthEarnings.toStringAsFixed(2)}'),
        _earningItem('Total', '\$${_data!.totalEarnings.toStringAsFixed(2)}'),
      ]),
    ]),
  );

  Widget _earningItem(String label, String value) => Expanded(child: Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
  ]));

  Widget _statsGrid() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: 0.06))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(Icons.bar_chart_rounded, size: 16, color: const Color(0xFF1A8CFF)), const SizedBox(width: 8),
        const Text('ESTADÍSTICAS DEL DÍA', style: TextStyle(color: Color(0xFF1A8CFF), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5))]),
      const SizedBox(height: 20),
      Row(children: [Expanded(child: _StatBox(icon: Icons.local_shipping, label: 'Envíos hoy', value: '${_data!.todayShipments}', color: const Color(0xFF1A8CFF))), const SizedBox(width: 12),
        Expanded(child: _StatBox(icon: Icons.people, label: 'Conductores', value: '${_data!.totalDrivers}', color: Colors.greenAccent))]),
      const SizedBox(height: 12),
      Row(children: [Expanded(child: _StatBox(icon: Icons.person, label: 'Usuarios totales', value: '${_data!.totalUsers}', color: Colors.orangeAccent)), const SizedBox(width: 12),
        Expanded(child: _StatBox(icon: Icons.directions_car, label: 'Vehículos activos', value: '${_data!.activeVehicles}', color: Colors.purpleAccent))]),
    ]),
  );

  Widget _summaryCard() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: 0.06))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(Icons.info_outline, size: 16, color: Colors.white.withValues(alpha: 0.5)), const SizedBox(width: 8),
        Text('RESUMEN GENERAL', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5))]),
      const SizedBox(height: 16),
      _infoRow(Icons.people_outline, 'Usuarios registrados', '${_data!.totalUsers}'),
      _infoRow(Icons.local_shipping, 'Conductores registrados', '${_data!.totalDrivers}'),
      _infoRow(Icons.directions_car, 'Vehículos activos ahora', '${_data!.activeVehicles}'),
      _infoRow(Icons.check_circle, 'Envíos completados hoy', '${_data!.todayShipments}'),
    ]),
  );

  Widget _infoRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.35)),
      const SizedBox(width: 12),
      Expanded(child: Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14))),
      Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
    ]),
  );
}

class _StatBox extends StatelessWidget {
  final IconData icon; final String label; final String value; final Color color;
  const _StatBox({required this.icon, required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withValues(alpha: 0.15))),
    child: Column(children: [
      Icon(icon, size: 24, color: color),
      const SizedBox(height: 8),
      Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
      Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11, fontWeight: FontWeight.w500)),
    ]),
  );
}

// ─── EDIT USER DIALOG ──────────────────────────────────────────────────

class _EditUserDialog extends StatefulWidget {
  final AdminUser user;
  const _EditUserDialog({required this.user});
  @override
  State<_EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<_EditUserDialog> {
  late TextEditingController _nombreCtrl;
  late TextEditingController _apellidoCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _telefonoCtrl;
  late TextEditingController _edadCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.user.nombre);
    _apellidoCtrl = TextEditingController(text: widget.user.apellido);
    _emailCtrl = TextEditingController(text: widget.user.email);
    _telefonoCtrl = TextEditingController(text: widget.user.telefono);
    _edadCtrl = TextEditingController(text: widget.user.edad?.toString());
  }

  @override
  void dispose() {
    _nombreCtrl.dispose(); _apellidoCtrl.dispose(); _emailCtrl.dispose();
    _telefonoCtrl.dispose(); _edadCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await AdminService().updateUser(widget.user.id, {
        'nombre': _nombreCtrl.text,
        'apellido': _apellidoCtrl.text,
        'email': _emailCtrl.text,
        'telefono': _telefonoCtrl.text,
        'edad': _edadCtrl.text.isNotEmpty ? int.tryParse(_edadCtrl.text) : null,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      title: const Text('Editar usuario', style: TextStyle(color: Colors.white, fontSize: 18)),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _field('Nombre', _nombreCtrl),
          const SizedBox(height: 12),
          _field('Apellido', _apellidoCtrl),
          const SizedBox(height: 12),
          _field('Email', _emailCtrl, keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 12),
          _field('Teléfono', _telefonoCtrl, keyboardType: TextInputType.phone),
          const SizedBox(height: 12),
          _field('Edad', _edadCtrl, keyboardType: TextInputType.number),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.white54))),
        TextButton(onPressed: _saving ? null : _save, child: _saving
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : const Text('Guardar', style: TextStyle(color: Color(0xFF1A8CFF)))),
      ],
    );
  }

  Widget _field(String label, TextEditingController ctrl, {TextInputType? keyboardType}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      TextField(
        controller: ctrl, keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          filled: true, fillColor: Colors.white.withValues(alpha: 0.06),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    ],
  );
}

// ─── USERS TAB ─────────────────────────────────────────────────────────

class _UsersTab extends StatefulWidget {
  const _UsersTab();
  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  final _service = AdminService();
  List<AdminUser>? _users;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final users = await _service.getUsers();
      if (mounted) setState(() { _users = users; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Color _roleColor(String? rol) {
    switch (rol) {
      case 'admin': return Colors.redAccent;
      case 'conductor': return const Color(0xFF1A8CFF);
      case 'cliente': return Colors.greenAccent;
      default: return Colors.grey;
    }
  }

  Future<void> _editUser(AdminUser user) async {
    final changed = await showDialog<bool>(context: context, builder: (_) => _EditUserDialog(user: user));
    if (changed == true) _load();
  }

  Future<void> _toggleSuspend(AdminUser user) async {
    try {
      await _service.toggleSuspendUser(user.id);
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _confirmDelete(AdminUser user) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Eliminar usuario', style: TextStyle(color: Colors.white)),
        content: Text('¿Eliminar a ${user.displayName.isNotEmpty ? user.displayName : user.email}?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (ok == true) {
      try {
        await _service.deleteUser(user.id);
        await _load();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: Color(0xFF1A8CFF)));
    if (_users == null) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('Error al cargar', style: TextStyle(color: Colors.white.withValues(alpha: 0.4))),
      const SizedBox(height: 16),
      ElevatedButton(onPressed: () { setState(() => _loading = true); _load(); }, child: const Text('Reintentar')),
    ]));
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _users!.length,
        itemBuilder: (_, i) {
          final u = _users![i];
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: u.suspendido ? Colors.red.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.06)),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: u.rol != 'admin' ? () => _editUser(u) : null,
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: _roleColor(u.rol).withValues(alpha: 0.2),
                    backgroundImage: u.avatar != null ? NetworkImage('${ApiClient.defaultBaseUrl.replaceAll('/api', '')}${u.avatar}') : null,
                    child: u.avatar == null
                        ? Text((u.nombre ?? u.email)[0].toUpperCase(), style: TextStyle(color: _roleColor(u.rol), fontWeight: FontWeight.bold))
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(u.displayName.isNotEmpty ? u.displayName : u.email,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                    Text(u.email, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _roleColor(u.rol).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(u.rol ?? '', style: TextStyle(color: _roleColor(u.rol), fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                    if (u.rol != 'admin') ...[
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => _toggleSuspend(u),
                        child: Icon(
                          u.suspendido ? Icons.check_circle_outline : Icons.block,
                          size: 18, color: u.suspendido ? Colors.greenAccent : Colors.orangeAccent,
                        ),
                      ),
                    ],
                  ]),
                  if (u.suspendido)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Suspendido', style: TextStyle(color: Colors.redAccent.withValues(alpha: 0.7), fontSize: 10, fontWeight: FontWeight.w600)),
                    ),
                ]),
                if (u.rol != 'admin') ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _confirmDelete(u),
                    child: Icon(Icons.delete_outline, size: 18, color: Colors.redAccent.withValues(alpha: 0.6)),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── DRIVERS TAB ───────────────────────────────────────────────────────

class _DriversTab extends StatefulWidget {
  const _DriversTab();
  @override
  State<_DriversTab> createState() => _DriversTabState();
}

class _DriversTabState extends State<_DriversTab> {
  final _service = AdminService();
  List<AdminDriver>? _drivers;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final drivers = await _service.getDrivers();
      if (mounted) setState(() { _drivers = drivers; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _toggleSuspend(AdminDriver d) async {
    try {
      await _service.toggleSuspendUser(d.usuarioId);
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: Color(0xFF1A8CFF)));
    if (_drivers == null) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('Error al cargar', style: TextStyle(color: Colors.white.withValues(alpha: 0.4))),
      const SizedBox(height: 16),
      ElevatedButton(onPressed: () { setState(() => _loading = true); _load(); }, child: const Text('Reintentar')),
    ]));
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _drivers!.length,
        itemBuilder: (_, i) {
          final d = _drivers![i];
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: d.suspendido ? Colors.red.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.06)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF1A8CFF).withValues(alpha: 0.2),
                  child: Text(d.placa[0].toUpperCase(), style: const TextStyle(color: Color(0xFF1A8CFF), fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(d.displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                    Text('${d.placa} · ${d.tipoVehiculo ?? ''}', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: d.online ? Colors.green.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(d.online ? 'En línea' : 'Offline', style: TextStyle(
                        color: d.online ? Colors.greenAccent : Colors.grey,
                        fontSize: 10, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _toggleSuspend(d),
                      child: Icon(
                        d.suspendido ? Icons.check_circle_outline : Icons.block,
                        size: 18, color: d.suspendido ? Colors.greenAccent : Colors.orangeAccent,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  if (d.suspendido)
                    Text('Suspendido', style: TextStyle(color: Colors.redAccent.withValues(alpha: 0.7), fontSize: 10, fontWeight: FontWeight.w600))
                  else
                    Text('${d.totalViajes ?? 0} viajes', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11)),
                ]),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── TRIPS TAB ─────────────────────────────────────────────────────────

class _TripsTab extends StatefulWidget {
  const _TripsTab();
  @override
  State<_TripsTab> createState() => _TripsTabState();
}

class _TripsTabState extends State<_TripsTab> {
  final _service = AdminService();
  List<AdminTrip>? _trips;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final trips = await _service.getTrips();
      if (mounted) setState(() { _trips = trips; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Color _estadoColor(String estado) {
    switch (estado) {
      case 'pendiente': return Colors.orangeAccent;
      case 'aceptado': return const Color(0xFF1A8CFF);
      case 'en_curso': return Colors.purpleAccent;
      case 'completado': return Colors.greenAccent;
      case 'finalizado': return Colors.green;
      case 'cancelado': return Colors.redAccent;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: Color(0xFF1A8CFF)));
    if (_trips == null) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('Error al cargar', style: TextStyle(color: Colors.white.withValues(alpha: 0.4))),
      const SizedBox(height: 16),
      ElevatedButton(onPressed: () { setState(() => _loading = true); _load(); }, child: const Text('Reintentar')),
    ]));
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _trips!.length,
        itemBuilder: (_, i) {
          final t = _trips![i];
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withValues(alpha: 0.06))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('#${t.id}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15))),
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: _estadoColor(t.estado).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                  child: Text(t.estado, style: TextStyle(color: _estadoColor(t.estado), fontSize: 11, fontWeight: FontWeight.w600))),
              ]),
              const SizedBox(height: 10),
              _tripRow(Icons.person, 'Cliente', t.clienteNombre),
              _tripRow(Icons.local_shipping, 'Conductor', t.conductorNombre.isNotEmpty ? t.conductorNombre : '—'),
              _tripRow(Icons.location_on, 'Origen', t.origenDireccion),
              _tripRow(Icons.flag, 'Destino', t.destinoDireccion),
              if (t.carga != null && t.carga!.isNotEmpty) _tripRow(Icons.inventory, 'Carga', t.carga!),
              _tripRow(Icons.attach_money, 'Precio', '\$${(t.precioFinal ?? t.precioEstimado ?? 0).toStringAsFixed(2)}'),
            ]),
          );
        },
      ),
    );
  }

  Widget _tripRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(children: [
      Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.3)),
      const SizedBox(width: 8),
      Text('$label: ', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
      Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 12))),
    ]),
  );
}

// ─── PAYMENTS TAB ──────────────────────────────────────────────────────

class _PaymentsTab extends StatefulWidget {
  final List<Map<String, dynamic>> payments;
  final VoidCallback onChanged;
  const _PaymentsTab({required this.payments, required this.onChanged});
  @override
  State<_PaymentsTab> createState() => _PaymentsTabState();
}

class _PaymentsTabState extends State<_PaymentsTab> {
  final _service = AdminService();
  List<Map<String, dynamic>> _payments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await _service.getPendingPayments();
      if (mounted) {
        setState(() {
          _payments = (res['payments'] as List<dynamic>?)
                  ?.map((e) => e as Map<String, dynamic>)
                  .toList() ??
              [];
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmPayment(String paymentId) async {
    try {
      await _service.confirmPayment(paymentId);
      await _load();
      widget.onChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pago confirmado'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _rejectPayment(String paymentId) async {
    try {
      await _service.rejectPayment(paymentId);
      await _load();
      widget.onChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pago rechazado'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: Color(0xFF1A8CFF)));
    final seen = <String>{};
    final allPayments = [..._payments, ...widget.payments].where((p) {
      final id = '${p['id'] ?? ''}';
      return id.isNotEmpty ? seen.add(id) : true;
    }).toList();
    if (allPayments.isEmpty) {
      return Center(
        child: Text('Sin pagos pendientes', style: TextStyle(color: Colors.white.withValues(alpha: 0.3))),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: allPayments.length,
        itemBuilder: (_, i) {
          final p = allPayments[i];
          final nombre = p['clienteNombre'] ?? 'Cliente';
          final monto = (p['monto'] ?? 0).toDouble();
          final comprobante = p['comprobante'] as String?;
          final createdAt = p['createdAt'] as String?;
          final id = '${p['id'] ?? ''}';
          final dias = p['diasEsperando'] ?? 0;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.greenAccent.withValues(alpha: 0.2),
                    child: const Icon(Icons.payment, size: 18, color: Colors.greenAccent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(nombre, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    Text('\$${monto.toStringAsFixed(2)}', style: const TextStyle(color: Colors.greenAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                  ])),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Icon(Icons.access_time, size: 14, color: Colors.white.withValues(alpha: 0.4)),
                  const SizedBox(width: 6),
                  Text('$dias día(s) esperando',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
                ]),
                if (createdAt != null) ...[
                  const SizedBox(height: 4),
                  Text('Subido: $createdAt',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 11)),
                ],
                if (comprobante != null && comprobante.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A8CFF).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(children: [
                      Icon(Icons.image, size: 16, color: const Color(0xFF1A8CFF)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('Comprobante',
                            style: TextStyle(color: const Color(0xFF1A8CFF), fontSize: 12)),
                      ),
                    ]),
                  ),
                ],
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: SizedBox(
                      height: 42,
                      child: ElevatedButton(
                        onPressed: () => _confirmPayment(id),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.greenAccent.withValues(alpha: 0.15),
                          foregroundColor: Colors.greenAccent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          side: BorderSide(color: Colors.greenAccent.withValues(alpha: 0.3)),
                        ),
                        child: const Text('Confirmar', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 42,
                      child: ElevatedButton(
                        onPressed: () => _rejectPayment(id),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent.withValues(alpha: 0.15),
                          foregroundColor: Colors.redAccent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.3)),
                        ),
                        child: const Text('Rechazar', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── EARNINGS TAB ──────────────────────────────────────────────────────

class _EarningsTab extends StatefulWidget {
  const _EarningsTab();
  @override
  State<_EarningsTab> createState() => _EarningsTabState();
}

class _EarningsTabState extends State<_EarningsTab> {
  final _service = AdminService();
  List<AdminEarning>? _earnings;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final earnings = await _service.getEarnings();
      if (mounted) setState(() { _earnings = earnings; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: Color(0xFF1A8CFF)));
    if (_earnings == null) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('Error al cargar', style: TextStyle(color: Colors.white.withValues(alpha: 0.4))),
      const SizedBox(height: 16),
      ElevatedButton(onPressed: () { setState(() => _loading = true); _load(); }, child: const Text('Reintentar')),
    ]));
    if (_earnings!.isEmpty) return Center(child: Text('Sin ganancias registradas', style: TextStyle(color: Colors.white.withValues(alpha: 0.3))));
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _earnings!.length,
        itemBuilder: (_, i) {
          final e = _earnings![i];
          final conductor = e.conductor;
          final nombre = conductor != null
              ? '${conductor['nombre'] ?? ''} ${conductor['apellido'] ?? ''}'.trim()
              : 'Conductor #${e.conductorId}';
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withValues(alpha: 0.06))),
            child: Row(children: [
              CircleAvatar(radius: 18, backgroundColor: Colors.greenAccent.withValues(alpha: 0.2),
                child: const Icon(Icons.monetization_on, size: 18, color: Colors.greenAccent)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('\$${e.monto.toStringAsFixed(2)}', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                if (nombre.isNotEmpty) Text(nombre, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
                if (e.createdAt != null) Text(e.createdAt!, style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 11)),
              ])),
              if (e.viaje != null)
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFF1A8CFF).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                  child: Text('Viaje #${e.viajeId}', style: const TextStyle(color: Color(0xFF1A8CFF), fontSize: 10, fontWeight: FontWeight.w600))),
            ]),
          );
        },
      ),
    );
  }
}
