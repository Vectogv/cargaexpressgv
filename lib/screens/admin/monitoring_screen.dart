import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/logger_service.dart';
import '../../services/performance_monitor.dart';
import '../../services/fraud_detection_service.dart';

const Color _primaryDark = Color(0xFF1A3C6E);
const Color _textDark = Color(0xFF1A1A2E);
const Color _textGrey = Color(0xFF757575);
const Color _bgLight = Color(0xFFF5F7FA);
const Color _white = Colors.white;
const Color _accentGreen = Color(0xFF4CAF50);
const Color _accentRed = Color(0xFFE53935);
const Color _accentOrange = Color(0xFFFF9800);

class MonitoringScreen extends StatefulWidget {
  const MonitoringScreen({super.key});

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  StreamSubscription<Map<String, dynamic>>? _logSub;
  StreamSubscription<FraudAlert>? _fraudSub;
  StreamSubscription<String>? _alertSub;
  final List<Map<String, dynamic>> _liveLogs = [];
  final List<FraudAlert> _fraudAlerts = [];
  final List<String> _autoAlerts = [];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);

    _logSub = LoggerService.instance.onLog.listen((log) {
      if (!mounted) return;
      setState(() {
        _liveLogs.insert(0, log);
        if (_liveLogs.length > 200) _liveLogs.removeLast();
      });
    });

    _fraudSub = FraudDetectionService.instance.onFraudAlert.listen((alert) {
      if (!mounted) return;
      setState(() => _fraudAlerts.insert(0, alert));
    });

    _alertSub = LoggerService.instance.onAutoAlert.listen((msg) {
      if (!mounted) return;
      setState(() => _autoAlerts.insert(0, msg));
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _logSub?.cancel();
    _fraudSub?.cancel();
    _alertSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final perf = PerformanceMonitor.instance.getSummary();

    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        backgroundColor: _white,
        foregroundColor: _textDark,
        elevation: 0.5,
        title: const Text('Monitoreo', style: TextStyle(fontWeight: FontWeight.w700)),
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          labelColor: _primaryDark,
          unselectedLabelColor: _textGrey,
          indicatorColor: _primaryDark,
          tabs: [
            Tab(text: 'Logs (${LoggerService.instance.getLogCount(level: LogLevel.error)})'),
            const Tab(text: 'Rendimiento'),
            const Tab(text: 'Alertas'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildLogsTab(),
          _buildPerformanceTab(perf),
          _buildAlertsTab(),
        ],
      ),
    );
  }

  Widget _buildLogsTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: _white,
          child: Row(children: [
            _FilterChip('Todos', null, () {}),
            const SizedBox(width: 6),
            _FilterChip('Error', LogLevel.error, () {
              setState(() {
                _liveLogs.removeWhere((l) => l['level'] != 'error');
              });
            }),
            const SizedBox(width: 6),
            _FilterChip('Warning', LogLevel.warning, () {
              setState(() {
                _liveLogs.removeWhere((l) => l['level'] != 'warning');
              });
            }),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              onPressed: () => setState(() { _liveLogs.clear(); LoggerService.instance.clearLogs(); }),
              tooltip: 'Limpiar logs',
            ),
            IconButton(
              icon: const Icon(Icons.download_outlined, size: 18),
              onPressed: () => LoggerService.instance.exportLogsToFile(),
              tooltip: 'Exportar logs',
            ),
          ]),
        ),
        Expanded(
          child: _liveLogs.isEmpty
              ? const Center(child: Text('Sin logs', style: TextStyle(color: _textGrey)))
              : ListView.builder(
                  itemCount: _liveLogs.length,
                  itemBuilder: (_, i) => _LogEntryCard(_liveLogs[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildPerformanceTab(Map<String, dynamic> summary) {
    final metrics = PerformanceMonitor.instance.getRecentMetrics(limit: 100);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Resumen', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _textDark)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _PerfCard('Promedio', '${summary['avg']}ms', _primaryDark)),
            const SizedBox(width: 8),
            Expanded(child: _PerfCard('M\u00e1ximo', '${summary['max']}ms', _accentOrange)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _PerfCard('Total', '${summary['count']}', _textGrey)),
            const SizedBox(width: 8),
            Expanded(child: _PerfCard('Lentos (>5s)', '${summary['slowCount']}', _accentRed)),
          ]),
          const SizedBox(height: 16),
          Text('Operaciones Recientes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _textDark)),
          const SizedBox(height: 8),
          ...metrics.map((m) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(children: [
              Icon(m['isError'] == true ? Icons.error : Icons.check_circle, size: 14, color: m['isError'] == true ? _accentRed : _accentGreen),
              const SizedBox(width: 6),
              Expanded(child: Text(m['label'] as String, style: const TextStyle(fontSize: 12))),
              Text('${m['durationMs']}ms', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: (m['durationMs'] as int) > 5000 ? _accentRed : _textDark)),
            ]),
          )),
        ],
      ),
    );
  }

  Widget _buildAlertsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_autoAlerts.isNotEmpty) ...[
            Text('Alertas Autom\u00e1ticas', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _accentRed)),
            const SizedBox(height: 8),
            ..._autoAlerts.map((a) => Card(
              margin: const EdgeInsets.symmetric(vertical: 2),
              color: _accentRed.withValues(alpha: 0.05),
              child: ListTile(
                leading: const Icon(Icons.warning_amber, color: _accentRed),
                title: Text(a, style: const TextStyle(fontSize: 13)),
              ),
            )),
            const SizedBox(height: 16),
          ],
          if (_fraudAlerts.isNotEmpty) ...[
            Text('Alertas de Fraude', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _accentOrange)),
            const SizedBox(height: 8),
            ..._fraudAlerts.take(50).map((a) => Card(
              margin: const EdgeInsets.symmetric(vertical: 2),
              child: ListTile(
                leading: Icon(
                  a.severity == 'high' ? Icons.gpp_bad : Icons.help_outline,
                  color: a.severity == 'high' ? _accentRed : _accentOrange,
                ),
                title: Text(a.message, style: const TextStyle(fontSize: 13)),
                subtitle: Text(a.type.name, style: TextStyle(fontSize: 11, color: _textGrey)),
                trailing: Text(a.severity, style: TextStyle(fontSize: 11, color: a.severity == 'high' ? _accentRed : _accentOrange)),
              ),
            )),
          ],
          if (_autoAlerts.isEmpty && _fraudAlerts.isEmpty)
            const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Sin alertas', style: TextStyle(color: _textGrey)))),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final LogLevel? level;
  final VoidCallback onTap;
  const _FilterChip(this.label, this.level, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: _textGrey.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label, style: const TextStyle(fontSize: 11)),
      ),
    );
  }
}

class _LogEntryCard extends StatelessWidget {
  final Map<String, dynamic> log;
  const _LogEntryCard(this.log);

  @override
  Widget build(BuildContext context) {
    final level = log['level'] as String? ?? '';
    Color color;
    switch (level) {
      case 'error': color = _accentRed; break;
      case 'warning': color = _accentOrange; break;
      default: color = _textGrey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _textGrey.withValues(alpha: 0.1))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8, height: 8, margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(log['message'] as String? ?? '', style: TextStyle(fontSize: 12, color: _textDark)),
                if (log['error'] != null)
                  Text(log['error'] as String, style: TextStyle(fontSize: 10, color: _textGrey)),
                Text(_formatTime(log['timestamp'] as String? ?? ''), style: TextStyle(fontSize: 9, color: _textGrey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String ts) {
    if (ts.isEmpty) return '';
    final dt = DateTime.tryParse(ts);
    if (dt == null) return '';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }
}

class _PerfCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  const _PerfCard(this.title, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(fontSize: 11, color: _textGrey)),
          ],
        ),
      ),
    );
  }
}
