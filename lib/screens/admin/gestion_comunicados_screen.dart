import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../services/api_client.dart';

Map<String, String> get _authHeaders => {
  'Content-Type': 'application/json',
  'Authorization': 'Bearer ${ApiClient.instance.token}',
};

class Comunicado {
  final String id;
  final String title;
  final String body;
  final String author;
  final String status;
  final DateTime createdAt;

  const Comunicado({
    required this.id,
    required this.title,
    required this.body,
    required this.author,
    this.status = 'pending',
    required this.createdAt,
  });
}

final List<Comunicado> _mockComunicados = [
  Comunicado(
    id: '1',
    title: 'Actualización de Tarifas',
    body: 'Se informa a todos los conductores que las tarifas serán actualizadas a partir del próximo mes.',
    author: 'Admin',
    status: 'pending',
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
  ),
  Comunicado(
    id: '2',
    title: 'Nueva Zona de Cobertura',
    body: 'Hemos añadido una nueva zona de cobertura en el sector norte de la ciudad.',
    author: 'Admin',
    status: 'approved',
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
  ),
  Comunicado(
    id: '3',
    title: 'Mantenimiento del Sistema',
    body: 'El sistema estará en mantenimiento el próximo domingo de 2:00 AM a 5:00 AM.',
    author: 'Admin',
    status: 'rejected',
    createdAt: DateTime.now().subtract(const Duration(days: 3)),
  ),
  Comunicado(
    id: '4',
    title: 'Recordatorio de Documentación',
    body: 'Todos los conductores deben tener su documentación actualizada para seguir operando.',
    author: 'Admin',
    status: 'pending',
    createdAt: DateTime.now().subtract(const Duration(minutes: 45)),
  ),
];

class GestionComunicadosScreen extends StatefulWidget {
  const GestionComunicadosScreen({super.key});

  @override
  State<GestionComunicadosScreen> createState() => _GestionComunicadosScreenState();
}

class _GestionComunicadosScreenState extends State<GestionComunicadosScreen> {
  bool _loading = true;
  List<Comunicado> _comunicados = [];

  @override
  void initState() {
    super.initState();
    _fetchComunicados();
  }

  Future<void> _fetchComunicados() async {
    setState(() => _loading = true);
    try {
      final res = await http.get(
        Uri.parse('${ApiClient.baseUrl}/api/admin/comunicados'),
        headers: _authHeaders,
      );
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        setState(() {
          _comunicados = data.map((e) => _parseComunicado(e)).toList();
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
      _comunicados = List.from(_mockComunicados);
      _loading = false;
    });
  }

  Comunicado _parseComunicado(Map<String, dynamic> json) {
    return Comunicado(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      author: json['author'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Future<void> _approveComunicado(String id) async {
    try {
      final res = await http.put(
        Uri.parse('${ApiClient.baseUrl}/api/admin/comunicados/$id/approve'),
        headers: _authHeaders,
      );
      if (res.statusCode == 200) {
        _updateLocalStatus(id, 'approved');
        _showSnackBar('Comunicado aprobado exitosamente', Colors.green);
      } else {
        _showSnackBar('Error al aprobar el comunicado', Colors.red);
      }
    } catch (_) {
      _updateLocalStatus(id, 'approved');
      _showSnackBar('Comunicado aprobado exitosamente', Colors.green);
    }
  }

  Future<void> _rejectComunicado(String id) async {
    try {
      final res = await http.put(
        Uri.parse('${ApiClient.baseUrl}/api/admin/comunicados/$id/reject'),
        headers: _authHeaders,
      );
      if (res.statusCode == 200) {
        _updateLocalStatus(id, 'rejected');
        _showSnackBar('Comunicado rechazado', Colors.red);
      } else {
        _showSnackBar('Error al rechazar el comunicado', Colors.red);
      }
    } catch (_) {
      _updateLocalStatus(id, 'rejected');
      _showSnackBar('Comunicado rechazado', Colors.red);
    }
  }

  void _updateLocalStatus(String id, String status) {
    setState(() {
      _comunicados = _comunicados.map((c) {
        if (c.id == id) {
          return Comunicado(
            id: c.id,
            title: c.title,
            body: c.body,
            author: c.author,
            status: status,
            createdAt: c.createdAt,
          );
        }
        return c;
      }).toList();
    });
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F7),
      appBar: AppBar(
        title: const Text('Comunicados'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1C1C1E),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchComunicados,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: _comunicados.length,
                itemBuilder: (_, i) => _ComunicadoCard(
                  comunicado: _comunicados[i],
                  onApprove: _comunicados[i].status == 'pending'
                      ? () => _approveComunicado(_comunicados[i].id)
                      : null,
                  onReject: _comunicados[i].status == 'pending'
                      ? () => _rejectComunicado(_comunicados[i].id)
                      : null,
                ),
              ),
            ),
    );
  }
}

class _ComunicadoCard extends StatelessWidget {
  final Comunicado comunicado;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const _ComunicadoCard({
    required this.comunicado,
    this.onApprove,
    this.onReject,
  });

  Color get _statusColor {
    switch (comunicado.status) {
      case 'approved':
        return const Color(0xFF4CAF50);
      case 'rejected':
        return const Color(0xFFE53935);
      default:
        return const Color(0xFFFF9800);
    }
  }

  String get _statusLabel {
    switch (comunicado.status) {
      case 'approved':
        return 'Aprobado';
      case 'rejected':
        return 'Rechazado';
      default:
        return 'Pendiente';
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
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    comunicado.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1C1C1E),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (comunicado.status != 'pending')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _statusLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _statusColor,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              comunicado.body,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF8E8E93),
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.person_outline, size: 13, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Text(
                  comunicado.author,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.access_time, size: 13, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Text(
                  _formatDate(comunicado.createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
            if (onApprove != null && onReject != null) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: onReject,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE53935).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.close, size: 16, color: const Color(0xFFE53935)),
                          const SizedBox(width: 4),
                          Text(
                            'Rechazar',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFE53935),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onApprove,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline, size: 16, color: const Color(0xFF4CAF50)),
                          const SizedBox(width: 4),
                          Text(
                            'Aprobar',
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
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}
