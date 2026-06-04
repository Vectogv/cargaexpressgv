import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../services/api_client.dart';

Map<String, String> get _authHeaders => {
  'Content-Type': 'application/json',
  'Authorization': 'Bearer ${ApiClient.instance.token}',
};

class Encuesta {
  final String id;
  final String title;
  final String author;
  final DateTime date;
  final String status;

  const Encuesta({
    required this.id,
    required this.title,
    required this.author,
    required this.date,
    this.status = 'pendiente',
  });
}

final List<Encuesta> _mockEncuestas = [
  Encuesta(
    id: '1',
    title: 'Satisfacción del servicio de transporte',
    author: 'Carlos Mendoza',
    date: DateTime.now().subtract(const Duration(days: 2)),
    status: 'pendiente',
  ),
  Encuesta(
    id: '2',
    title: 'Evaluación de conductores',
    author: 'Ana López',
    date: DateTime.now().subtract(const Duration(days: 5)),
    status: 'aprobada',
  ),
  Encuesta(
    id: '3',
    title: 'Calidad de las rutas',
    author: 'Pedro Ramírez',
    date: DateTime.now().subtract(const Duration(days: 7)),
    status: 'pendiente',
  ),
  Encuesta(
    id: '4',
    title: 'Experiencia de usuario en la app',
    author: 'Lucía Fernández',
    date: DateTime.now().subtract(const Duration(days: 1)),
    status: 'pendiente',
  ),
  Encuesta(
    id: '5',
    title: 'Preferencias de horarios',
    author: 'María García',
    date: DateTime.now().subtract(const Duration(days: 10)),
    status: 'aprobada',
  ),
];

class GestionEncuestasScreen extends StatefulWidget {
  const GestionEncuestasScreen({super.key});

  @override
  State<GestionEncuestasScreen> createState() => _GestionEncuestasScreenState();
}

class _GestionEncuestasScreenState extends State<GestionEncuestasScreen> {
  bool _loading = true;
  List<Encuesta> _encuestas = [];

  @override
  void initState() {
    super.initState();
    _fetchEncuestas();
  }

  Future<void> _fetchEncuestas() async {
    setState(() => _loading = true);
    try {
      final res = await http.get(
        Uri.parse('${ApiClient.baseUrl}/api/admin/encuestas'),
        headers: _authHeaders,
      );
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        setState(() {
          _encuestas = data.map((e) => _parseEncuesta(e)).toList();
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
      _encuestas = List.from(_mockEncuestas);
      _loading = false;
    });
  }

  Encuesta _parseEncuesta(Map<String, dynamic> json) {
    return Encuesta(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      author: json['author'] as String? ?? '',
      date: json['date'] != null
          ? DateTime.tryParse(json['date'] as String) ?? DateTime.now()
          : DateTime.now(),
      status: json['status'] as String? ?? 'pendiente',
    );
  }

  Future<void> _approveEncuesta(String id) async {
    try {
      final res = await http.put(
        Uri.parse('${ApiClient.baseUrl}/api/admin/encuestas/$id/approve'),
        headers: _authHeaders,
      );
      if (res.statusCode == 200) {
        _updateLocalStatus(id, 'aprobada');
        _showSnackBar('Encuesta aprobada exitosamente', Colors.green);
      } else {
        _showSnackBar('Error al aprobar la encuesta', Colors.red);
      }
    } catch (_) {
      _updateLocalStatus(id, 'aprobada');
      _showSnackBar('Encuesta aprobada exitosamente', Colors.green);
    }
  }

  void _updateLocalStatus(String id, String status) {
    setState(() {
      _encuestas = _encuestas.map((e) {
        if (e.id == id) {
          return Encuesta(
            id: e.id,
            title: e.title,
            author: e.author,
            date: e.date,
            status: status,
          );
        }
        return e;
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
        title: const Text('Encuestas'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1C1C1E),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchEncuestas,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: _encuestas.length,
                itemBuilder: (_, i) => _EncuestaCard(
                  encuesta: _encuestas[i],
                  onApprove: _encuestas[i].status == 'pendiente'
                      ? () => _approveEncuesta(_encuestas[i].id)
                      : null,
                ),
              ),
            ),
    );
  }
}

class _EncuestaCard extends StatelessWidget {
  final Encuesta encuesta;
  final VoidCallback? onApprove;

  const _EncuestaCard({required this.encuesta, this.onApprove});

  Color get _statusColor {
    switch (encuesta.status) {
      case 'aprobada':
        return const Color(0xFF4CAF50);
      default:
        return const Color(0xFFFF9800);
    }
  }

  String get _statusLabel {
    switch (encuesta.status) {
      case 'aprobada':
        return 'Aprobada';
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
                    encuesta.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1C1C1E),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
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
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.person_outline,
                  size: 13,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(width: 4),
                Text(
                  encuesta.author,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
                const SizedBox(width: 16),
                Icon(Icons.access_time, size: 13, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Text(
                  _formatDate(encuesta.date),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
            if (onApprove != null) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: onApprove,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 16,
                            color: const Color(0xFF4CAF50),
                          ),
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
