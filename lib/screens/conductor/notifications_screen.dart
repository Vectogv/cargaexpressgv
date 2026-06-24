import 'package:flutter/material.dart';
import '../../services/api_client.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;

  static const Color _textDark = Color(0xFF1A1A2E);
  static const Color _textGrey = Color(0xFF757575);
  static const Color _bgLight = Color(0xFFF5F7FA);
  static const Color _white = Colors.white;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    try {
      final notifs = await ApiClient.instance.getNotifications();
      if (mounted) setState(() { _notifications = notifs; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  IconData _iconForTipo(String? tipo) {
    switch (tipo) {
      case 'nuevo_viaje': return Icons.local_shipping_outlined;
      case 'viaje_aceptado': return Icons.check_circle_outline;
      case 'viaje_completado': return Icons.done_all;
      case 'viaje_cancelado': return Icons.cancel_outlined;
      case 'pago_recibido': return Icons.payments_outlined;
      case 'mensaje': return Icons.chat_bubble_outline;
      case 'documentacion': return Icons.description_outlined;
      default: return Icons.notifications_outlined;
    }
  }

  Color _colorForTipo(String? tipo) {
    switch (tipo) {
      case 'nuevo_viaje': return const Color(0xFF1565C0);
      case 'viaje_aceptado': return const Color(0xFFFF8F00);
      case 'viaje_completado': return const Color(0xFF2E7D32);
      case 'viaje_cancelado': return Colors.red;
      case 'pago_recibido': return const Color(0xFF6A1B9A);
      case 'mensaje': return const Color(0xFF00897B);
      case 'documentacion': return const Color(0xFFE65100);
      default: return const Color(0xFF757575);
    }
  }

  Color _bgForTipo(String? tipo) {
    switch (tipo) {
      case 'nuevo_viaje': return const Color(0xFFE3F2FD);
      case 'viaje_aceptado': return const Color(0xFFFFF8E1);
      case 'viaje_completado': return const Color(0xFFE8F5E9);
      case 'viaje_cancelado': return const Color(0xFFFFEBEE);
      case 'pago_recibido': return const Color(0xFFF3E5F5);
      case 'mensaje': return const Color(0xFFE0F2F1);
      case 'documentacion': return const Color(0xFFFBE9E7);
      default: return const Color(0xFFF5F5F5);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _notifications.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.notifications_none, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            const Text('Sin notificaciones', style: TextStyle(fontSize: 16, color: Colors.black45)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _notifications.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _buildNotifCard(_notifications[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: _white,
      padding: const EdgeInsets.only(top: 44, left: 16, right: 16, bottom: 14),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back_ios_new, size: 20),
          ),
          const SizedBox(width: 12),
          const Text('Notificaciones', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildNotifCard(Map<String, dynamic> notif) {
    final tipo = notif['tipo'] as String?;
    final leido = notif['leido'] == true;
    return InkWell(
      onTap: () => _onNotifTap(notif),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: _bgForTipo(tipo), borderRadius: BorderRadius.circular(12)),
              child: Icon(_iconForTipo(tipo), color: _colorForTipo(tipo), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notif['titulo'] as String? ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: leido ? FontWeight.w500 : FontWeight.w700,
                      color: _textDark,
                      height: 1.4,
                    ),
                  ),
                  if (notif['mensaje'] != null) ...[
                    const SizedBox(height: 2),
                    Text(notif['mensaje'] as String, style: TextStyle(fontSize: 12, color: _textGrey), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 4),
                  Text(_formatDate(notif['createdAt'] as String?), style: TextStyle(fontSize: 11, color: _textGrey)),
                ],
              ),
            ),
            if (!leido)
              Container(
                width: 9,
                height: 9,
                margin: const EdgeInsets.only(top: 4),
                decoration: const BoxDecoration(color: Color(0xFF1565C0), shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }

  void _onNotifTap(Map<String, dynamic> notif) {
    if (!notif['leido'] == true) {
      setState(() => notif['leido'] = true);
      ApiClient.instance.markNotificationRead(notif['id']).catchError((_) {});
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(notif['mensaje'] as String? ?? notif['titulo'] as String? ?? ''),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours}h';
    if (diff.inDays < 7) return 'Hace ${diff.inDays}d';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}