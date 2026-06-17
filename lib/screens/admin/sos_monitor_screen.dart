import 'package:flutter/material.dart';
import '../../services/api/http_client.dart';
import '../../models/sos_alert_model.dart';

class SosMonitorScreen extends StatefulWidget {
  const SosMonitorScreen({super.key});

  @override
  State<SosMonitorScreen> createState() => _SosMonitorScreenState();
}

class _SosMonitorScreenState extends State<SosMonitorScreen> {
  List<SosAlertModel> _alerts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchAlerts();
  }

  Future<void> _fetchAlerts() async {
    try {
      final list = await HttpClient.getList('/api/sos', auth: true);
      if (mounted) {
        setState(() {
          _alerts = list.cast<Map<String, dynamic>>().map((e) => SosAlertModel.fromJson(e)).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'pendiente': return 'Pendiente';
      case 'atendiendo': return 'En atención';
      case 'resuelto': return 'Resuelto';
      default: return status ?? 'Desconocido';
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'pendiente': return Colors.red;
      case 'atendiendo': return Colors.orange;
      case 'resuelto': return Colors.green;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        title: const Text('Alertas SOS', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchAlerts),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _alerts.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.shield_outlined, size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    const Text('No hay alertas SOS', style: TextStyle(fontSize: 16, color: Colors.black45)),
                  ]),
                )
              : RefreshIndicator(
                  onRefresh: _fetchAlerts,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _alerts.length,
                    itemBuilder: (_, i) => _buildAlertCard(_alerts[i]),
                  ),
                ),
    );
  }

  Widget _buildAlertCard(SosAlertModel alert) {
    final color = _statusColor(alert.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.warning_amber_rounded, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Conductor: ${alert.driverId ?? 'N/A'}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 2),
          Text('Viaje: ${alert.tripId ?? 'N/A'}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          if (alert.latitude != null && alert.longitude != null)
            Text('${alert.latitude!.toStringAsFixed(4)}, ${alert.longitude!.toStringAsFixed(4)}', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
            child: Text(_statusLabel(alert.status), style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
          ),
          if (alert.timestamp != null) ...[
            const SizedBox(height: 4),
            Text(_fmtTime(alert.timestamp!), style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
          ],
        ]),
      ]),
    );
  }

  String _fmtTime(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
