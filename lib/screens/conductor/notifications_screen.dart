import 'package:flutter/material.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  static const Color _primaryDark = Color(0xFF1A3C6E);
  static const Color _textDark = Color(0xFF1A1A2E);
  static const Color _textGrey = Color(0xFF757575);
  static const Color _bgLight = Color(0xFFF5F7FA);
  static const Color _white = Colors.white;

  final List<Map<String, dynamic>> _notifications = const [
    {
      'icon': Icons.local_shipping_outlined,
      'iconColor': Color(0xFF1565C0),
      'iconBg': Color(0xFFE3F2FD),
      'title': 'Nuevo viaje disponible en tu zona',
      'time': 'Hace 5 min',
      'unread': true,
    },
    {
      'icon': Icons.local_offer_outlined,
      'iconColor': Color(0xFFFF8F00),
      'iconBg': Color(0xFFFFF8E1),
      'title': 'Tu oferta fue recibida\n(ID: #4820)',
      'time': 'Hace 15 min',
      'unread': true,
    },
    {
      'icon': Icons.check_circle_outline,
      'iconColor': Color(0xFF2E7D32),
      'iconBg': Color(0xFFE8F5E9),
      'title': 'Viaje completado\n(ID: #4790)',
      'time': 'Hace 2 horas',
      'unread': false,
    },
    {
      'icon': Icons.payments_outlined,
      'iconColor': Color(0xFF6A1B9A),
      'iconBg': Color(0xFFF3E5F5),
      'title': 'Pago de comisión recibido',
      'time': 'Hace 1 día',
      'unread': false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _notifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) =>
                  _buildNotifCard(_notifications[index]),
            ),
          ),
          _buildMarkAll(),
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
          const Text('Notificaciones',
              style:
                  TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildNotifCard(Map<String, dynamic> notif) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: notif['iconBg'] as Color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(notif['icon'] as IconData,
                color: notif['iconColor'] as Color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notif['title'],
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: notif['unread']
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: _textDark,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(notif['time'],
                    style:
                        TextStyle(fontSize: 12, color: _textGrey)),
              ],
            ),
          ),
          if (notif['unread'])
            Container(
              width: 9,
              height: 9,
              margin: const EdgeInsets.only(top: 4),
              decoration: const BoxDecoration(
                color: Color(0xFF1565C0),
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMarkAll() {
    return Container(
      color: _white,
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: Text(
          'Marcar todas como leídas',
          style: TextStyle(
            color: _primaryDark,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

}
