import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../services/api_client.dart';

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

final List<Emergency> _mockEmergencies = [
  Emergency(
    id: '1',
    tag: 'Flagrant.melievalllat',
    title: 'Incidente Isaxocidente',
    subtitle: 'Incidente: Dexttorrio',
    location: 'Locación: Itariana, 211',
    priority: EmergencyPriority.critical,
    timestamp: DateTime.now().subtract(const Duration(minutes: 3)),
    isNew: true,
    status: 'active',
  ),
  Emergency(
    id: '2',
    tag: 'faft alerts',
    title: 'Incidente & Incidente',
    subtitle: 'Incidente: Soakoodo',
    location: 'Locación: Sitomere, 101',
    priority: EmergencyPriority.high,
    timestamp: DateTime.now().subtract(const Duration(minutes: 12)),
    isNew: false,
    status: 'active',
  ),
  Emergency(
    id: '3',
    tag: 'sys.monitor',
    title: 'Alerta de Sistema',
    subtitle: 'Incidente: Conexión perdida',
    location: 'Locación: Zona Norte, 45',
    priority: EmergencyPriority.medium,
    timestamp: DateTime.now().subtract(const Duration(minutes: 28)),
    isNew: false,
    status: 'active',
  ),
];

class EmergenciesScreen extends StatefulWidget {
  const EmergenciesScreen({super.key});

  @override
  State<EmergenciesScreen> createState() => _EmergenciesScreenState();
}

class _EmergenciesScreenState extends State<EmergenciesScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  int _selectedIndex = 0;
  bool _loading = true;
  List<Emergency> _emergencies = [];

  Map<String, String> get _authHeaders => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${ApiClient.instance.token}',
  };

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
      final res = await http.get(
        Uri.parse('${ApiClient.baseUrl}/api/admin/emergencies'),
        headers: _authHeaders,
      );
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        setState(() {
          _emergencies = data.map((e) => _parseEmergency(e)).toList();
          _loading = false;
        });
      } else {
        _useFallback();
      }
    } catch (_) {
      _useFallback();
    }
  }

  void _useFallback() {
    setState(() {
      _emergencies = List.from(_mockEmergencies);
      _loading = false;
    });
  }

  Emergency _parseEmergency(Map<String, dynamic> json) {
    final priorityStr = (json['priority'] as String? ?? 'medium').toLowerCase();
    final priority = priorityStr == 'critical'
        ? EmergencyPriority.critical
        : priorityStr == 'high'
            ? EmergencyPriority.high
            : EmergencyPriority.medium;
    return Emergency(
      id: json['id']?.toString() ?? '',
      tag: json['tag'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      location: json['location'] as String? ?? '',
      priority: priority,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      isNew: json['isNew'] == true,
      status: json['status'] as String? ?? 'active',
    );
  }

  Future<void> _resolveEmergency(String id) async {
    try {
      final res = await http.put(
        Uri.parse('${ApiClient.baseUrl}/api/admin/emergencies/$id/resolve'),
        headers: _authHeaders,
      );
      if (res.statusCode == 200) {
        await _fetchEmergencies();
      }
    } catch (_) {
      setState(() {
        _emergencies = _emergencies.map((e) {
          if (e.id == id) {
            return Emergency(
              id: e.id,
              tag: e.tag,
              title: e.title,
              subtitle: e.subtitle,
              location: e.location,
              priority: e.priority,
              timestamp: e.timestamp,
              isNew: e.isNew,
              status: 'resolved',
            );
          }
          return e;
        }).toList();
      });
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
          const Spacer(),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined,
                    color: Color(0xFF1C1C1E)),
                onPressed: () {},
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFD32F2F),
                    shape: BoxShape.circle,
                  ),
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
    Future.delayed(Duration(milliseconds: 80 * widget.index), _animCtrl.forward);
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
        Text(
          widget.emergency.location,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade500,
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
