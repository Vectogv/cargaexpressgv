import 'package:flutter/material.dart';
import '../../services/notification_service.dart';
import '../shared/tickets/ticket_detalle_screen.dart';
import '../shared/ui_compartida.dart' show TarjetaBlanca, ColoresApp;

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _service = NotificationService.instance;
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;
  bool _error = false;


  @override
  void initState() {
    super.initState();
    // Misma fuente que el badge de la campana: se muestra de inmediato lo que
    // hay en memoria y se completa con el backend.
    _notifications = _service.notifications;
    _service.unread.addListener(_sync);
    _fetchNotifications();
  }

  @override
  void dispose() {
    _service.unread.removeListener(_sync);
    super.dispose();
  }

  void _sync() {
    if (mounted) setState(() => _notifications = _service.notifications);
  }

  Future<void> _fetchNotifications() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    final ok = await _service.refresh();
    if (!mounted) return;
    setState(() {
      _notifications = _service.notifications;
      _loading = false;
      _error = !ok;
    });
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
      // Tipo persistido que el backend envía al cliente
      // (moderator_controller: cierre del viaje pasado a disputa).
      case 'disputa_cierre': return Icons.gavel_rounded;
      // Deuda de comisión vencida (DriverDebtSuspensionService).
      case 'suspension_por_pago': return Icons.money_off_rounded;
      // Búsqueda de conductor vencida sin ofertas aceptadas
      // (BusquedaTimeoutService, BUSQUEDA_TIMEOUT_MIN): al cliente.
      case 'busqueda_sin_conductor': return Icons.search_off_rounded;
      // Tickets de soporte: respuesta del staff o cambio de estado.
      case 'ticket_mensaje': return Icons.support_agent;
      case 'ticket_estado': return Icons.confirmation_number_outlined;
      default: return Icons.notifications_outlined;
    }
  }

  Color _colorForTipo(String? tipo) {
    switch (tipo) {
      case 'nuevo_viaje': return ColoresApp.azul;
      case 'viaje_aceptado': return ColoresApp.naranja;
      case 'viaje_completado': return ColoresApp.verdeOscuro;
      case 'viaje_cancelado': return Colors.red;
      case 'pago_recibido': return const Color(0xFF6A1B9A);
      case 'mensaje': return const Color(0xFF00897B);
      case 'documentacion': return ColoresApp.naranja;
      case 'disputa_cierre': return ColoresApp.naranja;
      case 'suspension_por_pago': return ColoresApp.rojo;
      case 'busqueda_sin_conductor': return ColoresApp.rojo;
      case 'ticket_mensaje':
      case 'ticket_estado':
        return ColoresApp.azul;
      default: return ColoresApp.grisClaro;
    }
  }

  Color _bgForTipo(String? tipo) {
    switch (tipo) {
      case 'nuevo_viaje': return ColoresApp.azulTenue;
      case 'viaje_aceptado': return ColoresApp.naranjaFondo;
      case 'viaje_completado': return ColoresApp.verdeFondo;
      case 'viaje_cancelado': return ColoresApp.rojoFondo;
      case 'pago_recibido': return const Color(0xFFF3E5F5);
      case 'mensaje': return const Color(0xFFE0F2F1);
      case 'documentacion': return ColoresApp.rojoFondo;
      case 'disputa_cierre': return ColoresApp.naranjaFondo;
      case 'suspension_por_pago': return ColoresApp.rojoFondo;
      case 'busqueda_sin_conductor': return ColoresApp.rojoFondo;
      case 'ticket_mensaje':
      case 'ticket_estado':
        return ColoresApp.azulTenue;
      default: return ColoresApp.fondo;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColoresApp.fondo,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_notifications.isEmpty) {
      if (_loading) return const Center(child: CircularProgressIndicator());
      return RefreshIndicator(
        onRefresh: _fetchNotifications,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 120),
            Icon(
              _error ? Icons.cloud_off_outlined : Icons.notifications_none,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 12),
            Text(
              _error ? 'No pudimos cargar tus notificaciones' : 'Sin notificaciones',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: Colors.black54),
            ),
            if (_error) ...[
              const SizedBox(height: 12),
              Center(
                child: OutlinedButton.icon(
                  onPressed: _fetchNotifications,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              ),
            ],
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchNotifications,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _notifications.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _buildNotifCard(_notifications[i]),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final hayNoLeidas = _notifications.any((n) => n['leido'] != true);
    return Container(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 8, 6),
          child: Row(
            children: [
              if (Navigator.canPop(context))
                IconButton(
                  tooltip: 'Volver',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                )
              else
                const SizedBox(width: 12),
              const Expanded(
                child: Text('Notificaciones', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              ),
              if (hayNoLeidas)
                TextButton(
                  onPressed: () => _service.markAllRead(),
                  child: const Text('Marcar todas leídas'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotifCard(Map<String, dynamic> notif) {
    final tipo = notif['tipo'] as String?;
    final leido = notif['leido'] == true;
    return InkWell(
      onTap: () => _onNotifTap(notif),
      borderRadius: BorderRadius.circular(14),
      child: TarjetaBlanca(
        radio: 14,
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
                      fontSize: 15,
                      fontWeight: leido ? FontWeight.w500 : FontWeight.w700,
                      color: ColoresApp.textoOscuro,
                      height: 1.4,
                    ),
                  ),
                  if (notif['mensaje'] != null) ...[
                    const SizedBox(height: 2),
                    Text(notif['mensaje'] as String, style: TextStyle(fontSize: 12, color: ColoresApp.textoSecundario), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 4),
                  Text(_formatDate(notif['createdAt'] as String?), style: TextStyle(fontSize: 12, color: ColoresApp.textoSecundario)),
                ],
              ),
            ),
            if (!leido)
              Container(
                width: 9,
                height: 9,
                margin: const EdgeInsets.only(top: 4),
                decoration: const BoxDecoration(color: ColoresApp.azul, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }

  void _onNotifTap(Map<String, dynamic> notif) {
    if (notif['leido'] != true) _service.markRead(notif);
    // Aviso de un ticket de soporte: abrir su detalle.
    final ticketId = notif['ticketId']?.toString();
    if (NotificationService.esTipoTicket(notif['tipo']?.toString()) && ticketId != null && ticketId.isNotEmpty) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => TicketDetalleScreen(ticketId: ticketId)));
      return;
    }
    final texto = notif['mensaje'] as String? ?? notif['titulo'] as String? ?? '';
    if (texto.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto), duration: const Duration(seconds: 2)),
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
