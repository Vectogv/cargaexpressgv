import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/api_client.dart';

Map<String, String> get _authHeaders => {
  'Content-Type': 'application/json',
  'Authorization': 'Bearer ${ApiClient.instance.token}',
};

enum ReportStatus { pendiente, revisado, resuelto, rechazado }

class ModeratorReport {
  final String id;
  final String moderatorName;
  final String reportType;
  final String description;
  final DateTime date;
  final ReportStatus status;

  const ModeratorReport({
    required this.id,
    required this.moderatorName,
    required this.reportType,
    required this.description,
    required this.date,
    required this.status,
  });

  factory ModeratorReport.fromJson(Map<String, dynamic> json) {
    return ModeratorReport(
      id: json['id']?.toString() ?? '',
      moderatorName: json['moderatorName']?.toString() ?? json['moderator_name']?.toString() ?? '',
      reportType: json['reportType']?.toString() ?? json['report_type']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      date: json['date'] != null
          ? DateTime.tryParse(json['date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      status: _parseStatus(json['status']?.toString()),
    );
  }

  static ReportStatus _parseStatus(String? s) {
    switch (s) {
      case 'pendiente':
        return ReportStatus.pendiente;
      case 'revisado':
        return ReportStatus.revisado;
      case 'resuelto':
        return ReportStatus.resuelto;
      case 'rechazado':
        return ReportStatus.rechazado;
      default:
        return ReportStatus.pendiente;
    }
  }
}

final List<ModeratorReport> _mockReports = [
  ModeratorReport(
    id: 'MR-001',
    moderatorName: 'Carlos López',
    reportType: 'Contenido inapropiado',
    description: 'El usuario publicó contenido ofensivo en la sección de comentarios del viaje #1234.',
    date: DateTime(2024, 12, 1),
    status: ReportStatus.pendiente,
  ),
  ModeratorReport(
    id: 'MR-002',
    moderatorName: 'Ana Martínez',
    reportType: 'Conflicto entre usuarios',
    description: 'Dos conductores tuvieron una discusión en la plataforma por la asignación de una ruta.',
    date: DateTime(2024, 11, 28),
    status: ReportStatus.revisado,
  ),
  ModeratorReport(
    id: 'MR-003',
    moderatorName: 'Pedro Ramírez',
    reportType: 'Solicitud de revisión',
    description: 'Solicita revisión de la decisión tomada sobre la cancelación del viaje #5678.',
    date: DateTime(2024, 11, 25),
    status: ReportStatus.resuelto,
  ),
  ModeratorReport(
    id: 'MR-004',
    moderatorName: 'Sofía García',
    reportType: 'Reporte de spam',
    description: 'Múltiples usuarios reportaron mensajes publicitarios no autorizados en el chat general.',
    date: DateTime(2024, 11, 22),
    status: ReportStatus.rechazado,
  ),
  ModeratorReport(
    id: 'MR-005',
    moderatorName: 'Luis Hernández',
    reportType: 'Error del sistema',
    description: 'La aplicación muestra un error al intentar cargar el historial de viajes del mes actual.',
    date: DateTime(2024, 11, 20),
    status: ReportStatus.pendiente,
  ),
];

class ModeratorReportsScreen extends StatefulWidget {
  const ModeratorReportsScreen({super.key});

  @override
  State<ModeratorReportsScreen> createState() => _ModeratorReportsScreenState();
}

class _ModeratorReportsScreenState extends State<ModeratorReportsScreen> {
  late List<ModeratorReport> _reports;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _reports = List.from(_mockReports);
    _fetchReports();
  }

  Future<void> _fetchReports() async {
    setState(() => _isLoading = true);
    try {
      final res = await http.get(
        Uri.parse('${ApiClient.baseUrl}/api/admin/moderator-reports'),
        headers: _authHeaders,
      );
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        setState(() {
          _reports = data.map((e) => ModeratorReport.fromJson(e)).toList();
          _isLoading = false;
        });
      } else {
        throw Exception('Error al obtener reportes');
      }
    } catch (_) {
      setState(() {
        _reports = List.from(_mockReports);
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: const Text(
          'Reportes de Moderadores',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A2E),
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF667EEA)),
            onPressed: _fetchReports,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchReports,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                itemCount: _reports.length,
                itemBuilder: (context, index) => _ReportCard(
                  report: _reports[index],
                ),
              ),
            ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final ModeratorReport report;
  const _ReportCard({required this.report});

  Color get _statusColor {
    switch (report.status) {
      case ReportStatus.pendiente:
        return const Color(0xFFE65100);
      case ReportStatus.revisado:
        return const Color(0xFF1565C0);
      case ReportStatus.resuelto:
        return const Color(0xFF2E7D32);
      case ReportStatus.rechazado:
        return const Color(0xFFC62828);
    }
  }

  Color get _statusBg {
    switch (report.status) {
      case ReportStatus.pendiente:
        return const Color(0xFFFFF3E0);
      case ReportStatus.revisado:
        return const Color(0xFFE3F2FD);
      case ReportStatus.resuelto:
        return const Color(0xFFE8F5E9);
      case ReportStatus.rechazado:
        return const Color(0xFFFFEBEE);
    }
  }

  IconData get _statusIcon {
    switch (report.status) {
      case ReportStatus.pendiente:
        return Icons.schedule_rounded;
      case ReportStatus.revisado:
        return Icons.visibility_rounded;
      case ReportStatus.resuelto:
        return Icons.check_circle_rounded;
      case ReportStatus.rechazado:
        return Icons.cancel_rounded;
    }
  }

  String get _statusLabel {
    switch (report.status) {
      case ReportStatus.pendiente:
        return 'Pendiente';
      case ReportStatus.revisado:
        return 'Revisado';
      case ReportStatus.resuelto:
        return 'Resuelto';
      case ReportStatus.rechazado:
        return 'Rechazado';
    }
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
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Container(
              height: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_statusColor, _statusColor.withValues(alpha: 0.4)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F3F7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          report.id,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade600,
                            fontFamily: 'Courier',
                          ),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _statusBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_statusIcon, size: 12, color: _statusColor),
                            const SizedBox(width: 4),
                            Text(
                              _statusLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _DetailRow(
                    icon: Icons.person_outline_rounded,
                    label: 'Moderador',
                    value: report.moderatorName,
                  ),
                  const SizedBox(height: 6),
                  _DetailRow(
                    icon: Icons.category_outlined,
                    label: 'Tipo',
                    value: report.reportType,
                  ),
                  const SizedBox(height: 6),
                  _DetailRow(
                    icon: Icons.description_outlined,
                    label: 'Descripción',
                    value: report.description,
                  ),
                  const SizedBox(height: 6),
                  _DetailRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'Fecha',
                    value: '${report.date.day.toString().padLeft(2, '0')}/${report.date.month.toString().padLeft(2, '0')}/${report.date.year}',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 13, color: Colors.grey.shade500),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF1A1A2E),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
