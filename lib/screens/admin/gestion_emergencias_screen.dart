import 'package:flutter/material.dart';
import '../../services/api/http_client.dart';
import 'admin_common.dart';

enum EmergencyPriority { critical, high, medium }

class Emergency {
  final String id;
  final String tag;
  final String title;
  final String subtitle;
  final String location;
  final EmergencyPriority priority;
  final DateTime timestamp;
  final bool isNew;
  final String status;

  const Emergency({
    required this.id,
    required this.tag,
    required this.title,
    required this.subtitle,
    required this.location,
    required this.priority,
    required this.timestamp,
    this.isNew = false,
    this.status = 'active',
  });
}

class EmergenciesScreen extends StatefulWidget {
  const EmergenciesScreen({super.key});

  @override
  State<EmergenciesScreen> createState() => _EmergenciesScreenState();
}

class _EmergenciesScreenState extends State<EmergenciesScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _loading = true;
  List<Emergency> _emergencies = [];
  String? _error;

  int get _activeCount =>
      _emergencies.where((e) => e.status != 'resolved').length;

  int get _criticalCount =>
      _emergencies.where((e) => e.priority == EmergencyPriority.critical && e.status != 'resolved').length;

  int get _highCount =>
      _emergencies.where((e) => e.priority == EmergencyPriority.high && e.status != 'resolved').length;

  int get _mediumCount =>
      _emergencies.where((e) => e.priority == EmergencyPriority.medium && e.status != 'resolved').length;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _fetchEmergencies();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _fetchEmergencies() async {
    setState(() => _loading = true);
    try {
      final data = await HttpClient.getList('/api/admin/emergencies', auth: true);
      if (!mounted) return;
      setState(() {
        _emergencies = adminMapList(data).map(_parseEmergency).toList();
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = adminErrorText(e);
        _loading = false;
      });
    }
  }

  /// Backend: {id, userId, viajeId, lat, lng, atendida, motivo?,
  /// usuario{nombre,apellido,telefono}, viaje{origen,destino,estado}, createdAt}.
  /// No hay prioridad en el backend: una alerta con viaje en curso es crítica,
  /// con viaje asignado alta, y sin viaje media.
  Emergency _parseEmergency(Map<String, dynamic> json) {
    final usuario = json['usuario'] is Map ? json['usuario'] as Map : const {};
    final viaje = json['viaje'] is Map ? json['viaje'] as Map : null;
    final estadoViaje = viaje?['estado']?.toString();
    final priority = estadoViaje == 'en_curso'
        ? EmergencyPriority.critical
        : viaje != null
            ? EmergencyPriority.high
            : EmergencyPriority.medium;
    final created = DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toLocal() ?? DateTime.now();
    final nombre = '${usuario['nombre'] ?? ''} ${usuario['apellido'] ?? ''}'.trim();
    final lat = json['lat'];
    final lng = json['lng'];
    return Emergency(
      id: json['id']?.toString() ?? '',
      tag: 'SOS #${json['id'] ?? ''}${json['viajeId'] != null ? ' · Viaje #${json['viajeId']}' : ''}',
      title: nombre.isNotEmpty ? nombre : 'Usuario #${json['userId'] ?? ''}',
      subtitle: [
        if (json['motivo'] != null) json['motivo'].toString(),
        if (usuario['telefono'] != null) 'Tel: ${usuario['telefono']}',
        if (viaje != null) '${viaje['origen'] ?? ''} → ${viaje['destino'] ?? ''}',
      ].join(' · '),
      location: lat != null && lng != null ? 'Ubicación: $lat, $lng' : 'Ubicación no disponible',
      priority: priority,
      timestamp: created,
      isNew: DateTime.now().difference(created).inMinutes < 10,
      status: json['atendida'] == true ? 'resolved' : 'active',
    );
  }

  Future<void> _resolveEmergency(String id) async {
    try {
      await HttpClient.put('/api/admin/emergencies/$id/resolve', auth: true);
      adminSnack(this, 'Emergencia marcada como atendida', color: const Color(0xFF4CAF50));
      await _fetchEmergencies();
    } catch (e) {
      adminSnack(this, adminErrorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildStatsBar(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _fetchEmergencies,
                      child: _buildEmergencyList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5E5EA), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Color.lerp(
                    const Color(0xFFFFEBEE),
                    const Color(0xFFFFCDD2),
                    _pulseController.value,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.crisis_alert_rounded,
                  color: Color(0xFFD32F2F),
                  size: 20,
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'EMERGENCIAS',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1C1C1E),
                  letterSpacing: 0.3,
                ),
              ),
              Text(
                'GET /api/admin/emergencies',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                  letterSpacing: 0.2,
                  fontFamily: 'Courier',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Row(
        children: [
          _StatChip(
            label: 'Activas',
            value: '$_activeCount',
            color: const Color(0xFFD32F2F),
          ),
          const SizedBox(width: 8),
          _StatChip(
            label: 'Críticas',
            value: '$_criticalCount',
            color: const Color(0xFFE53935),
          ),
          const SizedBox(width: 8),
          _StatChip(
            label: 'Alta',
            value: '$_highCount',
            color: const Color(0xFFFF9800),
          ),
          const SizedBox(width: 8),
          _StatChip(
            label: 'Media',
            value: '$_mediumCount',
            color: const Color(0xFF2196F3),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyList() {
    if (_emergencies.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(32),
        children: [
          Center(
            child: Text(
              _error ?? 'Sin emergencias activas',
              textAlign: TextAlign.center,
              style: TextStyle(color: _error != null ? Colors.red : Colors.black54),
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _emergencies.length,
      itemBuilder: (_, i) => _EmergencyCard(
        emergency: _emergencies[i],
        index: i,
        onResolve: _emergencies[i].status != 'resolved'
            ? () => _resolveEmergency(_emergencies[i].id)
            : null,
      ),
    );
  }
}

class _EmergencyCard extends StatefulWidget {
  final Emergency emergency;
  final int index;
  final VoidCallback? onResolve;
  const _EmergencyCard({
    required this.emergency,
    required this.index,
    this.onResolve,
  });

  @override
  State<_EmergencyCard> createState() => _EmergencyCardState();
}

class _EmergencyCardState extends State<_EmergencyCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0.05, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.easeOutCubic,
    ));
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(_animCtrl);
    // Escalonado limitado y protegido: la tarjeta puede desmontarse antes.
    Future.delayed(Duration(milliseconds: 80 * widget.index.clamp(0, 8)), () {
      if (mounted) _animCtrl.forward();
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Color get _priorityColor {
    switch (widget.emergency.priority) {
      case EmergencyPriority.critical:
        return const Color(0xFFD32F2F);
      case EmergencyPriority.high:
        return const Color(0xFFFF9800);
      case EmergencyPriority.medium:
        return const Color(0xFF2196F3);
    }
  }

  String get _priorityLabel {
    switch (widget.emergency.priority) {
      case EmergencyPriority.critical:
        return 'CRÍTICO';
      case EmergencyPriority.high:
        return 'ALTA';
      case EmergencyPriority.medium:
        return 'MEDIA';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnim,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _priorityColor.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              children: [
                _buildPriorityBar(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTopRow(),
                      const SizedBox(height: 8),
                      _buildTitle(),
                      const SizedBox(height: 4),
                      _buildSubtitle(),
                      const SizedBox(height: 6),
                      _buildLocation(),
                      if (widget.onResolve != null) ...[
                        const SizedBox(height: 12),
                        _buildResolveButton(),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResolveButton() {
    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onTap: widget.onResolve,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline,
                  size: 16, color: const Color(0xFF4CAF50)),
              const SizedBox(width: 6),
              Text(
                'Resolver',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF4CAF50),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityBar() {
    return Container(
      height: 4,
      color: _priorityColor,
    );
  }

  Widget _buildTopRow() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: _priorityColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_amber_rounded, size: 11, color: _priorityColor),
              const SizedBox(width: 4),
              Text(
                widget.emergency.tag,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _priorityColor,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        if (widget.emergency.isNew)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'NUEVO',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: Color(0xFFD32F2F),
                letterSpacing: 0.5,
              ),
            ),
          ),
        const SizedBox(width: 6),
        Text(
          _priorityLabel,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: _priorityColor,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildTitle() {
    return Text(
      widget.emergency.title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1C1C1E),
      ),
    );
  }

  Widget _buildSubtitle() {
    return Text(
      widget.emergency.subtitle,
      style: const TextStyle(
        fontSize: 13,
        color: Color(0xFF8E8E93),
      ),
    );
  }

  Widget _buildLocation() {
    return Row(
      children: [
        Icon(Icons.location_on_outlined,
            size: 13, color: Colors.grey.shade400),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            widget.emergency.location,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}
