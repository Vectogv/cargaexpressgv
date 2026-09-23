import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../services/api/http_client.dart';
import '../../services/socket_service_client.dart';
import '../../services/notification_service.dart';
import '../user/auth_screen.dart';
import 'admin_common.dart';

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
    with SingleTickerProviderStateMixin, VisiblePolling {
  late TabController _tabCtrl;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _trips = [];
  /// Conductores en un notifier: las ubicaciones por socket llegan con mucha
  /// frecuencia y solo deben reconstruir lo que muestra conductores.
  final ValueNotifier<List<Map<String, dynamic>>> _drivers = ValueNotifier(const []);
  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _disputes = [];
  List<Map<String, dynamic>> _cancellations = [];
  List<Map<String, dynamic>> _emergencies = [];
  int _notifUnread = 0;
  StreamSubscription<Map<String, dynamic>>? _driverLocSub;
  StreamSubscription<Map<String, dynamic>>? _disputeSub;
  StreamSubscription<Map<String, dynamic>>? _cancelSub;
  StreamSubscription<Map<String, dynamic>>? _emergencySub;
  StreamSubscription<dynamic>? _notifSub;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 7, vsync: this);
    _notifUnread = NotificationService.instance.unreadCount;
    _notifSub = NotificationService.instance.onNotification.listen((_) {
      if (mounted) setState(() => _notifUnread = NotificationService.instance.unreadCount);
    });
    _initSocket();
    _fetchAll();

    // Solo sondea mientras esta pantalla está visible y la app en primer plano.
    startPolling(const Duration(seconds: 15), _fetchAll);
  }

  void _initSocket() {
    _driverLocSub = SocketServiceClient.instance.onAdminDriverLocation.listen((data) {
      if (!mounted) return;
      final dataId = (data['_id'] ?? data['id'] ?? data['conductorId'])?.toString();
      if (dataId == null) return;
      final list = List<Map<String, dynamic>>.of(_drivers.value);
      final idx = list.indexWhere((d) => (d['_id'] ?? d['id'])?.toString() == dataId);
      if (idx >= 0) {
        list[idx] = Map<String, dynamic>.from(list[idx])..addAll(data);
      } else {
        list.add(data);
      }
      _drivers.value = list;
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
    _notifSub?.cancel();
    _drivers.dispose();
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

  /// GET de lista con manejo uniforme de errores: guarda el mensaje del
  /// backend para mostrarlo (sin tragarse el fallo) y conserva datos previos.
  Future<List<Map<String, dynamic>>?> _getList(String path) async {
    try {
      final list = adminMapList(await HttpClient.getList(path, auth: true));
      if (mounted && _error != null) setState(() => _error = null);
      return list;
    } catch (e) {
      if (mounted) setState(() => _error = adminErrorText(e));
      return null;
    }
  }

  Future<void> _fetchTrips() async {
    final list = await _getList('/api/admin/trips');
    if (list != null && mounted) setState(() => _trips = list);
  }

  Future<void> _fetchDrivers() async {
    final list = await _getList('/api/admin/drivers');
    if (list != null && mounted) _drivers.value = list;
  }

  Future<void> _fetchClients() async {
    // El backend filtra por rol (antes se filtraba en el cliente solo la 1a página).
    final list = await _getList('/api/admin/users?rol=cliente&limit=100');
    if (list != null && mounted) setState(() => _clients = list);
  }

  Future<void> _fetchDisputes() async {
    final list = await _getList('/api/admin/disputes');
    if (list != null && mounted) setState(() => _disputes = list);
  }

  Future<void> _fetchCancellations() async {
    final list = await _getList('/api/admin/cancellation-requests');
    if (list != null && mounted) setState(() => _cancellations = list);
  }

  Future<void> _fetchEmergencies() async {
    final list = await _getList('/api/admin/emergencies');
    if (list != null && mounted) setState(() => _emergencies = list);
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
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Badge(
              isLabelVisible: _notifUnread > 0,
              label: Text('$_notifUnread'),
              child: IconButton(
                tooltip: 'Notificaciones',
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () => showAdminNotificationsSheet(
                  context,
                  onMarkedAllRead: () {
                    if (mounted) setState(() => _notifUnread = 0);
                  },
                ),
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
          : Column(
              children: [
                if (_error != null)
                  MaterialBanner(
                    backgroundColor: const Color(0xFFFFEBEE),
                    content: Text(_error!, style: const TextStyle(color: _accentRed)),
                    actions: [TextButton(onPressed: _fetchAll, child: const Text('Reintentar'))],
                  ),
                Expanded(
                  child: TabBarView(
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
                ),
              ],
            ),
    );
  }

  Widget _buildOverviewTab() {
    final activeTrips = _trips.where((t) {
      final e = t['estado'] as String?;
      return e == 'aceptado' || e == 'en_curso';
    }).length;
    // Disputas: el backend solo lista estado abierta/en_revision.
    final pendingDisputes = _disputes.where((d) {
      final e = d['estado'] as String? ?? 'abierta';
      return e == 'abierta' || e == 'en_revision';
    }).length;
    // Emergencias: el backend solo lista las no atendidas (atendida=false).
    final activeEmergencies = _emergencies.where((e) => e['atendida'] != true).length;
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
              Expanded(
                child: ValueListenableBuilder<List<Map<String, dynamic>>>(
                  valueListenable: _drivers,
                  builder: (_, drivers, _) {
                    final online = drivers.where((d) => d['online'] == true || d['conectado'] == true).length;
                    return _StatCard('Conductores Online', '$online', Icons.drive_eta, _accentGreen);
                  },
                ),
              ),
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
      events.add({'icon': Icons.crisis_alert, 'color': _accentRed, 'text': 'Emergencia: ${_personName(e['usuario']) ?? e['motivo'] ?? ''}', 'time': e['createdAt'] ?? ''});
    }
    for (final d in _disputes.take(3)) {
      events.add({'icon': Icons.gavel, 'color': _accentOrange, 'text': 'Disputa: ${d['problema'] ?? d['versionCliente'] ?? '#${d['id']}'}', 'time': d['createdAt'] ?? ''});
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
    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: _drivers,
      builder: (_, drivers, _) {
        if (drivers.isEmpty) {
          return const Center(child: Text('Sin conductores conectados', style: TextStyle(color: _textGrey)));
        }
        return RefreshIndicator(
          onRefresh: _fetchDrivers,
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: drivers.length,
            itemBuilder: (_, i) => _DriverCard(drivers[i]),
          ),
        );
      },
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

/// "Nombre Apellido" de un objeto usuario/cliente/conductor del backend.
String? _personName(dynamic p) {
  if (p is! Map) return null;
  final n = '${p['nombre'] ?? p['name'] ?? ''} ${p['apellido'] ?? ''}'.trim();
  return n.isEmpty ? null : n;
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
    // Backend: origenDireccion/destinoDireccion (texto).
    final origen = trip['origenDireccion']?.toString() ?? '';
    final destino = trip['destinoDireccion']?.toString() ?? '';

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
              _InfoRow(Icons.person, 'Conductor: ${_personName(conductor) ?? ''}'),
            if (cliente != null)
              _InfoRow(Icons.person_outline, 'Cliente: ${_personName(cliente) ?? ''}'),
            if (origen.isNotEmpty) _InfoRow(Icons.location_on, origen),
            if (destino.isNotEmpty) _InfoRow(Icons.flag, destino),
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
    // Backend: usuario{nombre, apellido}, ultimaUbicacion{lat,lng}, totalViajes.
    // El socket admin:driver:location agrega lat/lng en la raíz.
    final nombre = _personName(driver['usuario']) ?? _personName(driver) ?? (driver['placa']?.toString() ?? '');
    final ubic = driver['ultimaUbicacion'] is Map ? driver['ultimaUbicacion'] as Map : const {};
    final lat = double.tryParse((driver['lat'] ?? ubic['lat'])?.toString() ?? '');
    final lng = double.tryParse((driver['lng'] ?? ubic['lng'])?.toString() ?? '');
    final activeTrips = driver['totalViajes'] ?? 0;

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
    final nombre = _personName(client) ?? '';
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
    // Backend: estado (abierta|en_revision|resuelta), problema (socket),
    // versionCliente / versionConductor, viajeId.
    final status = dispute['estado'] as String? ?? 'abierta';
    final motivo = dispute['problema']?.toString() ?? 'Viaje #${dispute['viajeId'] ?? ''}';
    final desc = dispute['versionCliente']?.toString() ?? dispute['versionConductor']?.toString() ?? '';

    Color statusColor;
    switch (status) {
      case 'abierta': statusColor = _accentOrange; break;
      case 'en_revision': statusColor = _primaryDark; break;
      case 'resuelta': statusColor = _accentGreen; break;
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
                child: Text(status.replaceAll('_', ' '), style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w600)),
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
    final motivo = cancel['motivo']?.toString() ?? '';
    final conductor = _personName(cancel['conductor']);
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
              Expanded(
                child: Text(
                  'Viaje #${cancel['tripId'] ?? cancel['viajeId'] ?? cancel['id'] ?? ''}${conductor != null ? ' \u00b7 $conductor' : ''}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
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
    // Backend: atendida, usuario{nombre,apellido,telefono}, viaje{origen,destino}; motivo (socket).
    final status = emergency['atendida'] == true ? 'resolved' : 'active';
    final usuario = emergency['usuario'];
    final title = _personName(usuario) ?? '';
    final viaje = emergency['viaje'] is Map ? emergency['viaje'] as Map : null;
    final desc = [
      if (emergency['motivo'] != null) emergency['motivo'].toString(),
      if (usuario is Map && usuario['telefono'] != null) 'Tel: ${usuario['telefono']}',
      if (viaje != null) '${viaje['origen'] ?? ''} → ${viaje['destino'] ?? ''}',
    ].join('\n');

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
