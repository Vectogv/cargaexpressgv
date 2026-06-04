import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../services/api_client.dart';

Map<String, String> get _authHeaders => {
  'Content-Type': 'application/json',
  'Authorization': 'Bearer ${ApiClient.instance.token}',
};

class Dispute {
  final String id;
  final String title;
  final String user;
  final String status;
  final String description;

  const Dispute({
    required this.id,
    required this.title,
    required this.user,
    required this.status,
    required this.description,
  });

  factory Dispute.fromJson(Map<String, dynamic> json) {
    return Dispute(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      user: json['user']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      description: json['description']?.toString() ?? '',
    );
  }
}

final List<Dispute> _mockDisputes = [
  const Dispute(
    id: 'D-001',
    title: 'Cobro duplicado',
    user: 'Juan Pérez',
    status: 'pending',
    description: 'El conductor realizó dos cobros por el mismo viaje.',
  ),
  const Dispute(
    id: 'D-002',
    title: 'Daño en la carga',
    user: 'María García',
    status: 'resolved',
    description: 'La mercancía llegó con daños visibles en el embalaje.',
  ),
  const Dispute(
    id: 'D-003',
    title: 'Retraso en la entrega',
    user: 'Carlos López',
    status: 'pending',
    description: 'El paquete se entregó 3 días después de lo acordado.',
  ),
];

class DisputesScreen extends StatefulWidget {
  const DisputesScreen({super.key});

  @override
  State<DisputesScreen> createState() => _DisputesScreenState();
}

class _DisputesScreenState extends State<DisputesScreen> {
  List<Dispute> _disputes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDisputes();
  }

  Future<void> _fetchDisputes() async {
    setState(() => _isLoading = true);
    try {
      final res = await http.get(
        Uri.parse('${ApiClient.baseUrl}/api/admin/disputes'),
        headers: _authHeaders,
      );
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        setState(() {
          _disputes = data.map((e) => Dispute.fromJson(e)).toList();
          _isLoading = false;
        });
      } else {
        throw Exception('Error al obtener disputas');
      }
    } catch (_) {
      setState(() {
        _disputes = List.from(_mockDisputes);
        _isLoading = false;
      });
    }
  }

  Future<void> _resolveDispute(String id) async {
    TextEditingController resolutionCtrl = TextEditingController();

    final resolution = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Resolver disputa'),
        content: TextFormField(
          controller: resolutionCtrl,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Resolución',
            hintText: 'Describe la resolución...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, resolutionCtrl.text.trim()),
            child: const Text('Resolver'),
          ),
        ],
      ),
    );

    if (resolution == null || resolution.isEmpty) return;

    try {
      final res = await http.put(
        Uri.parse('${ApiClient.baseUrl}/api/admin/disputes/$id/resolve'),
        headers: _authHeaders,
        body: jsonEncode({'resolution': resolution}),
      );
      if (res.statusCode == 200) {
        _fetchDisputes();
      } else {
        throw Exception('Error al resolver disputa');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al resolver la disputa, usa el fallback')),
        );
      }
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'resolved':
        return const Color(0xFF2E7D32);
      case 'rejected':
        return const Color(0xFFC62828);
      case 'pending':
      default:
        return const Color(0xFFE65100);
    }
  }

  Color _statusBg(String status) {
    switch (status) {
      case 'resolved':
        return const Color(0xFFE8F5E9);
      case 'rejected':
        return const Color(0xFFFFEBEE);
      case 'pending':
      default:
        return const Color(0xFFFFF3E0);
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'resolved':
        return Icons.check_circle_rounded;
      case 'rejected':
        return Icons.cancel_rounded;
      case 'pending':
      default:
        return Icons.schedule_rounded;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'resolved':
        return 'Resuelto';
      case 'rejected':
        return 'Rechazado';
      case 'pending':
      default:
        return 'Pendiente';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F7),
      appBar: AppBar(
        title: const Text(
          'Disputas',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A2E),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: Color(0xFF1A1A2E)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF1A1A2E)),
            onPressed: _fetchDisputes,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchDisputes,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _disputes.length,
                itemBuilder: (context, index) => _buildDisputeCard(_disputes[index]),
              ),
            ),
    );
  }

  Widget _buildDisputeCard(Dispute dispute) {
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
                  colors: [
                    _statusColor(dispute.status),
                    _statusColor(dispute.status).withValues(alpha: 0.4),
                  ],
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
                          color: const Color(0xFFF2F2F7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          dispute.id,
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
                          color: _statusBg(dispute.status),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_statusIcon(dispute.status),
                                size: 12, color: _statusColor(dispute.status)),
                            const SizedBox(width: 4),
                            Text(
                              _statusLabel(dispute.status),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _statusColor(dispute.status),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    dispute.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.person_outline_rounded,
                          size: 13, color: Colors.grey.shade500),
                      const SizedBox(width: 6),
                      Text(
                        'Usuario: ',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          dispute.user,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF1A1A2E),
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Icon(Icons.description_outlined,
                            size: 13, color: Colors.grey.shade500),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          dispute.description,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF555555),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.visibility_outlined, size: 14),
                          label: const Text('Ver'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF667EEA),
                            side: const BorderSide(
                                color: Color(0xFF667EEA), width: 1),
                            padding:
                                const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            textStyle: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: dispute.status == 'resolved'
                              ? null
                              : () => _resolveDispute(dispute.id),
                          icon: const Icon(Icons.check_circle_outline_rounded, size: 14),
                          label: const Text('Resolver'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF667EEA),
                            disabledBackgroundColor: Colors.grey.shade300,
                            padding:
                                const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            textStyle: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
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
