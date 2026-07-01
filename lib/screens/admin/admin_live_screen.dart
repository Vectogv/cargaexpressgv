import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/api_client.dart';
import '../../services/socket_service_client.dart';
import '../../services/notification_service.dart';
import '../user/auth_screen.dart';

Map<String, String> get _authHeaders => {
  'Content-Type': 'application/json',
  'Authorization': 'Bearer ${ApiClient.instance.token}',
};

const Color _primaryDark = Color(0xFF1A3C6E);
const Color _textDark = Color(0xFF1A1A2E);
const Color _textGrey = Color(0xFF757575);
const Color _bgLight = Color(0xFFF5F7FA);
const Color _white = Colors.white;
const Color _accentGreen = Color(0xFF4CAF50);
const Color _accentRed = Color(0xFFE53935);
const Color _accentOrange = Color(0xFFFF9800);

class AdminLiveScreen extends StatefulWidget {
  const AdminLiveScreen({super.key});

  @override
  State<AdminLiveScreen> createState() => _AdminLiveScreenState();
}

class _AdminLiveScreenState extends State<AdminLiveScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _loading = true;
  List<Map<String, dynamic>> _trips = [];
  List<Map<String, dynamic>> _drivers = [];
  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _disputes = [];
  List<Map<String, dynamic>> _cancellations = [];
  List<Map<String, dynamic>> _emergencies = [];
  int _notifUnread = 0;
  StreamSubscription<Map<String, dynamic>>? _driverLocSub;
  StreamSubscription<Map<String, dynamic>>? _disputeSub;
  StreamSubscription<Map<String, dynamic>>? _cancelSub;
  StreamSubscription<Map<String, dynamic>>? _emergencySub;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 7, vsync: this);
    _notifUnread = NotificationService.instance.unreadCount;
    NotificationService.instance.onNotification.listen((_) {
      if (mounted) setState(() => _notifUnread = NotificationService.instance.unreadCount);
    });
    _initSocket();
    _fetchAll();

    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) _fetchAll();
    });
  }

  void _initSocket() {
    _driverLocSub = SocketServiceClient.instance.onAdminDriverLocation.listen((data) {
      if (!mounted) return;
      setState(() {
        final idx = _drivers.indexWhere((d) => d['id']?.toString() == data['id']?.toString());
        if (idx >= 0) {
          _drivers[idx] = Map<String, dynamic>.from(_drivers[idx])..addAll(data);
        } else {
          _drivers.add(data);
        }
      });
    });

    _disputeSub = SocketServiceClient.instance.onAdminDispute.listen((data) {
      if (!mounted) return;
      setState(() => _disputes.insert(0, data));
    });

    _cancelSub = SocketServiceClient.instance.onAdminCancellation.listen((data) {
      if (!mounted) return;
      setState(() => _cancellations.insert(0, data));
    });

    _emergencySub = SocketServiceClient.instance.onAdminEmergency.listen((data) {
      if (!mounted) return;
      setState(() => _emergencies.insert(0, data));
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _driverLocSub?.cancel();
    _disputeSub?.cancel();
    _cancelSub?.cancel();
    _emergencySub?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchAll() async {
    await Future.wait([
      _fetchTrips(),
      _fetchDrivers(),
      _fetchClients(),
      _fetchDisputes(),
      _fetchCancellations(),
      _fetchEmergencies(),
    ]);
    if (mounted && _loading) setState(() => _loading = false);
  }

  Future<void> _fetchTrips() async {
    try {
      final res = await http.get(
        Uri.parse('${ApiClient.baseUrl}/api/admin/trips'),
        headers: _authHeaders,
      );
      if (res.statusCode == 200 && mounted) {
        setState(() => _trips = List<Map<String, dynamic>>.from(jsonDecode(res.body)));
      }
    } catch (_) {}
  }

  Future<void> _fetchDrivers() async {
    try {
      final res = await http.get(
        Uri.parse('${ApiClient.baseUrl}/api/admin/drivers'),
        headers: _authHeaders,
      );
      if (res.statusCode == 200 && mounted) {
        setState(() => _drivers = List<Map<String, dynamic>>.from(jsonDecode(res.body)));
      }
    } catch (_) {}
  }

  Future<void> _fetchClients() async {
    try {
      final res = await http.get(
        Uri.parse('${ApiClient.baseUrl}/api/admin/clients'),
        headers: _authHeaders,
      );
      if (res.statusCode == 200 && mounted) {
        setState(() => _clients = List<Map<String, dynamic>>.from(jsonDecode(res.body)));
      }
    } catch (_) {}
  }

  Future<void> _fetchDisputes() async {
    try {
      final res = await http.get(
        Uri.parse('${ApiClient.baseUrl}/api/admin/disputes'),
        headers: _authHeaders,
      );
      if (res.statusCode == 200 && mounted) {
        setState(() => _disputes = List<Map<String, dynamic>>.from(jsonDecode(res.body)));
      }
    } catch (_) {}
  }

  Future<void> _fetchCancellations() async {
    try {
      final res = await http.get(
        Uri.parse('${ApiClient.baseUrl}/api/admin/cancellations'),
        headers: _authHeaders,
      );
      if (res.statusCode == 200 && mounted) {
        setState(() => _cancellations = List<Map<String, dynamic>>.from(jsonDecode(res.body)));
      }
    } catch (_) {}
  }

  Future<void> _fetchEmergencies() async {
    try {
      final res = await http.get(
        Uri.parse('${ApiClient.baseUrl}/api/admin/emergencies'),
        headers: _authHeaders,
      );
      if (res.statusCode == 200 && mounted) {
        setState(() => _emergencies = List<Map<String, dynamic>>.from(jsonDecode(res.body)));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        backgroundColor: _white,
        foregroundColor: _textDark,
        elevation: 0.5,
        title: Row(
          children: [
            const Text('Panel en Vivo', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20)),
            const SizedBox(width: 8),
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: SocketServiceClient.instance.isConnected ? _accentGreen : _accentRed,
              ),
            ),
          ],
        ),
        actions: [
          if (_notifUnread > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Badge(
                label: Text('$_notifUnread'),
                child: IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () {},
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchAll,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ApiClient.instance.logout();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context, MaterialPageRoute(builder: (_) => const AuthScreen()), (_) => false,
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller: _tabCtrl,
            isScrollable: true,
            labelColor: _primaryDark,
            unselectedLabelColor: _textGrey,
            indicatorColor: _primaryDark,
            tabs: const [
              Tab(text: 'Resumen'),
              Tab(text: 'Viajes'),
              Tab(text: 'Conductores'),
              Tab(text: 'Clientes'),
              Tab(text: 'Disputas'),
              Tab(text: 'Cancelaciones'),
              Tab(text: 'Emergencias'),
            ],
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _buildOverviewTab(),
                _buildTripsTab(),
                _buildDriversTab(),
                _buildClientsTab(),
                _buildDisputesTab(),
                _buildCancellationsTab(),
                _buildEmergenciesTab(),
              ],
            ),
    );
  }

  Widget _buildOverviewTab() {
    final activeTrips = _trips.where((t) {
      final e = t['estado'] as String?;
      return e == 'aceptado' || e == 'en_curso';
    }).length;
    final onlineDrivers = _drivers.where((d) => d['online'] == true || d['conectado'] == true).length;
    final pendingDisputes = _disputes.where((d) => (d['status'] as String? ?? '') == 'pending').length;
    final activeEmergencies = _emergencies.where((e) => (e['status'] as String? ?? '') == 'active').length;
    final todayCancellations = _cancellations.length;

    return RefreshIndicator(
      onRefresh: _fetchAll,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: _StatCard('Viajes Activos', '$activeTrips', Icons.route, _primaryDark)),
              const SizedBox(width: 8),
              Expanded(child: _StatCard('Conductores Online', '$onlineDrivers', Icons.drive_eta, _accentGreen)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _StatCard('Disputas Pendientes', '$pendingDisputes', Icons.gavel, _accentOrange)),
              const SizedBox(width: 8),
              Expanded(child: _StatCard('Alertas', '$activeEmergencies', Icons.crisis_alert, _accentRed)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _StatCard('Cancelaciones Hoy', '$todayCancellations', Icons.cancel, _textGrey)),
              const SizedBox(width: 8),
              Expanded(child: _StatCard('Clientes', '${_clients.length}', Icons.people, _primaryDark)),
            ]),
            const SizedBox(height: 16),
            Text('Eventos Recientes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _textDark)),
            const SizedBox(height: 8),
            ..._buildRecentEvents(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildRecentEvents() {
    final events = <Map<String, dynamic>>[];
    for (final e in _emergencies.take(3)) {
      events.add({'icon': Icons.crisis_alert, 'color': _accentRed, 'text': 'Emergencia: ${e['title'] ?? ''}', 'time': e['createdAt'] ?? ''});
    }
    for (final d in _disputes.take(3)) {
      events.add({'icon': Icons.gavel, 'color': _accentOrange, 'text': 'Disputa: ${d['title'] ?? d['motivo'] ?? ''}', 'time': d['createdAt'] ?? ''});
    }
    for (final c in _cancellations.take(3)) {
      events.add({'icon': Icons.cancel, 'color': _accentRed, 'text': 'Cancelaci\u00f3n: ${c['motivo'] ?? ''}', 'time': c['createdAt'] ?? ''});
    }
    events.sort((a, b) {
      final ta = a['time']?.toString() ?? '';
      final tb = b['time']?.toString() ?? '';
      return tb.compareTo(ta);
    });

    if (events.isEmpty) {
      return [Padding(padding: const EdgeInsets.all(16), child: Text('Sin eventos recientes', style: TextStyle(color: _textGrey)))];
    }

    return events.take(10).map((e) => ListTile(
      dense: true,
      leading: Icon(e['icon'] as IconData, color: e['color'] as Color, size: 20),
      title: Text(e['text'] as String, style: const TextStyle(fontSize: 13)),
      trailing: Text(_formatTime(e['time']?.toString()), style: TextStyle(fontSize: 11, color: _textGrey)),
    )).toList();
  }

  Widget _buildTripsTab() {
    if (_trips.isEmpty) {
      return const Center(child: Text('Sin viajes activos', style: TextStyle(color: _textGrey)));
    }
    return RefreshIndicator(
      onRefresh: _fetchTrips,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _trips.length,
        itemBuilder: (_, i) => _TripCard(_trips[i]),
      ),
    );
  }

  Widget _buildDriversTab() {
    if (_drivers.isEmpty) {
      return const Center(child: Text('Sin conductores conectados', style: TextStyle(color: _textGrey)));
    }
    return RefreshIndicator(
      onRefresh: _fetchDrivers,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _drivers.length,
        itemBuilder: (_, i) => _DriverCard(_drivers[i]),
      ),
    );
  }

  Widget _buildClientsTab() {
    if (_clients.isEmpty) {
      return const Center(child: Text('Sin clientes activos', style: TextStyle(color: _textGrey)));
    }
    return RefreshIndicator(
      onRefresh: _fetchClients,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _clients.length,
        itemBuilder: (_, i) => _ClientCard(_clients[i]),
      ),
    );
  }

  Widget _buildDisputesTab() {
    if (_disputes.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchDisputes,
        child: ListView(
          children: const [Center(child: Padding(padding: EdgeInsets.all(32), child: Text('Sin disputas', style: TextStyle(color: _textGrey))))],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchDisputes,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _disputes.length,
        itemBuilder: (_, i) => _DisputeCard(_disputes[i]),
      ),
    );
  }

  Widget _buildCancellationsTab() {
    if (_cancellations.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchCancellations,
        child: ListView(
          children: const [Center(child: Padding(padding: EdgeInsets.all(32), child: Text('Sin cancelaciones recientes', style: TextStyle(color: _textGrey))))],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchCancellations,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _cancellations.length,
        itemBuilder: (_, i) => _CancellationCard(_cancellations[i]),
      ),
    );
  }

  Widget _buildEmergenciesTab() {
    if (_emergencies.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchEmergencies,
        child: ListView(
          children: const [Center(child: Padding(padding: EdgeInsets.all(32), child: Text('Sin emergencias activas', style: TextStyle(color: _textGrey))))],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchEmergencies,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _emergencies.length,
        itemBuilder: (_, i) => _EmergencyCard(_emergencies[i]),
      ),
    );
  }

  String _formatTime(String? ts) {
    if (ts == null || ts.isEmpty) return '';
    final dt = DateTime.tryParse(ts);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'ahora';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}

// --- Reusable widgets ---

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard(this.title, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _textDark)),
                Text(title, style: TextStyle(fontSize: 11, color: _textGrey)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  final Map<String, dynamic> trip;
  const _TripCard(this.trip);

  @override
  Widget build(BuildContext context) {
    final estado = trip['estado'] as String? ?? '';
    final conductor = trip['conductor'] as Map<String, dynamic>?;
    final cliente = trip['cliente'] as Map<String, dynamic>?;
    final origen = trip['origen'] as Map<String, dynamic>?;
    final destino = trip['destino'] as Map<String, dynamic>?;

    Color estadoColor;
    switch (estado) {
      case 'buscando_conductor': estadoColor = _accentOrange; break;
      case 'aceptado': estadoColor = _primaryDark; break;
      case 'en_curso': estadoColor = _accentGreen; break;
      case 'esperando_confirmacion': estadoColor = _textGrey; break;
      default: estadoColor = _textGrey;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: estadoColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                child: Text(estado.replaceAll('_', ' '), style: TextStyle(fontSize: 11, color: estadoColor, fontWeight: FontWeight.w600)),
              ),
              const Spacer(),
              Text('#${trip['id']}', style: TextStyle(fontSize: 11, color: _textGrey)),
            ]),
            const SizedBox(height: 8),
            if (conductor != null)
              _InfoRow(Icons.person, 'Conductor: ${conductor['nombre'] ?? conductor['name'] ?? ''}'),
            if (cliente != null)
              _InfoRow(Icons.person_outline, 'Cliente: ${cliente['nombre'] ?? cliente['name'] ?? ''}'),
            if (origen != null)
              _InfoRow(Icons.location_on, origen['direccion']?.toString() ?? origen['address']?.toString() ?? ''),
            if (destino != null)
              _InfoRow(Icons.flag, destino['direccion']?.toString() ?? destino['address']?.toString() ?? ''),
          ],
        ),
      ),
    );
  }
}

class _DriverCard extends StatelessWidget {
  final Map<String, dynamic> driver;
  const _DriverCard(this.driver);

  @override
  Widget build(BuildContext context) {
    final online = driver['online'] == true || driver['conectado'] == true;
    final nombre = driver['nombre'] as String? ?? driver['name'] as String? ?? '';
    final lat = double.tryParse(driver['latitude']?.toString() ?? driver['lat']?.toString() ?? '');
    final lng = double.tryParse(driver['longitude']?.toString() ?? driver['lng']?.toString() ?? '');
    final activeTrips = driver['activeTrips'] ?? driver['viajesActivos'] ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: online ? _accentGreen.withValues(alpha: 0.15) : _textGrey.withValues(alpha: 0.15),
          child: Icon(Icons.drive_eta, color: online ? _accentGreen : _textGrey),
        ),
        title: Text(nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: online ? _accentGreen : _textGrey)),
              const SizedBox(width: 4),
              Text(online ? 'En l\u00ednea' : 'Desconectado', style: TextStyle(fontSize: 12, color: online ? _accentGreen : _textGrey)),
            ]),
            if (lat != null && lng != null)
              Text('${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}', style: TextStyle(fontSize: 10, color: _textGrey)),
          ],
        ),
        trailing: Text('$activeTrips viajes', style: TextStyle(fontSize: 11, color: _textGrey)),
      ),
    );
  }
}

class _ClientCard extends StatelessWidget {
  final Map<String, dynamic> client;
  const _ClientCard(this.client);

  @override
  Widget build(BuildContext context) {
    final nombre = client['nombre'] as String? ?? client['name'] as String? ?? '';
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: _primaryDark.withValues(alpha: 0.1), child: const Icon(Icons.person, color: _primaryDark)),
        title: Text(nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(client['email']?.toString() ?? '', style: TextStyle(fontSize: 12, color: _textGrey)),
      ),
    );
  }
}

class _DisputeCard extends StatelessWidget {
  final Map<String, dynamic> dispute;
  const _DisputeCard(this.dispute);

  @override
  Widget build(BuildContext context) {
    final status = dispute['status'] as String? ?? 'pending';
    final motivo = dispute['title'] as String? ?? dispute['motivo'] as String? ?? '';
    final desc = dispute['description'] as String? ?? dispute['descripcion'] as String? ?? '';

    Color statusColor;
    switch (status) {
      case 'pending': statusColor = _accentOrange; break;
      case 'resolved': statusColor = _accentGreen; break;
      case 'dismissed': statusColor = _textGrey; break;
      default: statusColor = _textGrey;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                child: Text(status, style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w600)),
              ),
              const Spacer(),
              Text('#${dispute['id']}', style: TextStyle(fontSize: 11, color: _textGrey)),
            ]),
            const SizedBox(height: 6),
            Text(motivo, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            if (desc.isNotEmpty) ...[const SizedBox(height: 4), Text(desc, style: TextStyle(fontSize: 12, color: _textGrey))],
          ],
        ),
      ),
    );
  }
}

class _CancellationCard extends StatelessWidget {
  final Map<String, dynamic> cancel;
  const _CancellationCard(this.cancel);

  @override
  Widget build(BuildContext context) {
    final motivo = cancel['motivo'] as String? ?? cancel['reason'] as String? ?? '';
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.cancel, color: _accentRed, size: 18),
              const SizedBox(width: 6),
              Text('Cancelaci\u00f3n #${cancel['id'] ?? cancel['tripId'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ]),
            if (motivo.isNotEmpty) ...[const SizedBox(height: 4), Text(motivo, style: TextStyle(fontSize: 12, color: _textGrey))],
          ],
        ),
      ),
    );
  }
}

class _EmergencyCard extends StatelessWidget {
  final Map<String, dynamic> emergency;
  const _EmergencyCard(this.emergency);

  @override
  Widget build(BuildContext context) {
    final status = emergency['status'] as String? ?? 'active';
    final title = emergency['title'] as String? ?? '';
    final desc = emergency['description'] as String? ?? emergency['subtitle'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: status == 'active' ? _accentRed.withValues(alpha: 0.15) : _accentGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status == 'active' ? 'ACTIVA' : 'RESUELTA',
                  style: TextStyle(fontSize: 11, color: status == 'active' ? _accentRed : _accentGreen, fontWeight: FontWeight.w700),
                ),
              ),
              const Spacer(),
              Icon(Icons.crisis_alert, color: status == 'active' ? _accentRed : _accentGreen, size: 18),
            ]),
            if (title.isNotEmpty) ...[const SizedBox(height: 6), Text(title, style: const TextStyle(fontWeight: FontWeight.w600))],
            if (desc.isNotEmpty) ...[const SizedBox(height: 4), Text(desc, style: TextStyle(fontSize: 12, color: _textGrey))],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(children: [
        Icon(icon, size: 14, color: _textGrey),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: TextStyle(fontSize: 12, color: _textDark))),
      ]),
    );
  }
}
