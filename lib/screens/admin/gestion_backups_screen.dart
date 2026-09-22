import 'package:flutter/material.dart';
import '../../services/api/http_client.dart';
import 'admin_common.dart';

class BackupLog {
  final String id;
  final DateTime date;
  final String filename;
  final String description;
  final String status;

  const BackupLog({
    required this.id,
    required this.date,
    required this.filename,
    this.description = '',
    required this.status,
  });
}

class BackupsScreen extends StatefulWidget {
  const BackupsScreen({super.key});

  @override
  State<BackupsScreen> createState() => _BackupsScreenState();
}

class _BackupsScreenState extends State<BackupsScreen> {
  bool _loading = true;
  bool _running = false;
  List<BackupLog> _backups = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchBackups();
  }

  Future<void> _fetchBackups() async {
    setState(() => _loading = true);
    try {
      final data = await HttpClient.getList('/api/admin/backups', auth: true);
      if (!mounted) return;
      setState(() {
        _backups = adminMapList(data).map(_parseBackupLog).toList();
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

  /// Backend: {id, fecha, estado: exitoso|fallido, archivo, driveId, errorMensaje, createdAt}
  BackupLog _parseBackupLog(Map<String, dynamic> json) {
    final fecha = (json['fecha'] ?? json['createdAt'])?.toString();
    return BackupLog(
      id: json['id']?.toString() ?? '',
      date: (fecha != null ? DateTime.tryParse(fecha)?.toLocal() : null) ?? DateTime.now(),
      filename: json['archivo']?.toString() ?? '',
      description: json['errorMensaje']?.toString() ??
          (json['driveId'] != null ? 'Subido a Drive (${json['driveId']})' : ''),
      status: json['estado']?.toString() ?? 'exitoso',
    );
  }

  Future<void> _runManualBackup() async {
    setState(() => _running = true);
    try {
      final res = await HttpClient.post('/api/admin/backups/run', body: const {}, auth: true);
      adminSnack(this, res['message']?.toString() ?? 'Respaldo manual completado');
    } catch (e) {
      adminSnack(this, adminErrorText(e), error: true);
    }
    if (!mounted) return;
    setState(() => _running = false);
    await _fetchBackups();
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'exitoso':
      case 'completado':
        return const Color(0xFF34C759);
      case 'fallido':
      case 'error':
        return const Color(0xFFFF3B30);
      case 'en progreso':
      case 'running':
        return const Color(0xFF007AFF);
      default:
        return const Color(0xFF8E8E93);
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'exitoso':
      case 'completado':
        return Icons.check_circle_rounded;
      case 'fallido':
      case 'error':
        return Icons.error_rounded;
      case 'en progreso':
      case 'running':
        return Icons.sync_rounded;
      default:
        return Icons.help_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F7),
      appBar: AppBar(
        title: const Text('Backups'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1C1C1E),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchBackups,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _running ? null : _runManualBackup,
        backgroundColor: const Color(0xFF007AFF),
        foregroundColor: Colors.white,
        icon: _running
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.play_arrow_rounded),
        label: Text(_running ? 'Ejecutando...' : 'Ejecutar Backup Manual'),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _fetchBackups,
                child: _backups.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.all(32),
                        children: [
                          Center(
                            child: Text(
                              _error ?? 'Sin respaldos registrados',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: _error != null ? Colors.red : Colors.black54),
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                        itemCount: _backups.length,
                        itemBuilder: (_, i) => _BackupCard(
                          backup: _backups[i],
                          statusColor: _statusColor(_backups[i].status),
                          statusIcon: _statusIcon(_backups[i].status),
                        ),
                      ),
              ),
      ),
    );
  }
}

class _BackupCard extends StatelessWidget {
  final BackupLog backup;
  final Color statusColor;
  final IconData statusIcon;

  const _BackupCard({
    required this.backup,
    required this.statusColor,
    required this.statusIcon,
  });

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year} ${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        backup.filename,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1C1C1E),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (backup.description.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          backup.description,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8E8E93),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.calendar_today_rounded,
                    size: 13, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Text(
                  _formatDate(backup.date),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    backup.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
