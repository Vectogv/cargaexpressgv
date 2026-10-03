import 'package:flutter/material.dart';
import '../../services/notification_service.dart';
import '../../widgets/error_carga.dart';
import '../shared/tickets/ticket_detalle_screen.dart';
import '../shared/ui_compartida.dart' show TarjetaBlanca, ColoresApp;

/// Bandeja de avisos (cliente y conductor): agrupada por día, con ícono y
/// color por categoría, no leídas resaltadas y "Marcar todas como leídas".
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

enum _Categoria { viaje, pago, soporte, grupo, sistema }

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

  static _Categoria _categoria(String? tipo) {
    switch (tipo) {
      case 'nuevo_viaje':
      case 'viaje_aceptado':
      case 'viaje_completado':
      case 'viaje_cancelado':
      case 'viaje_estado':
      case 'disputa_cierre':
      case 'disputa_resuelta':
      case 'busqueda_sin_conductor':
        return _Categoria.viaje;
      case 'pago_recibido':
      case 'suspension_por_pago':
        return _Categoria.pago;
      case 'ticket_mensaje':
      case 'ticket_estado':
        return _Categoria.soporte;
      case 'mensaje':
      case 'conversacion_mensaje':
        return _Categoria.grupo;
      default:
        return _Categoria.sistema;
    }
  }

  static Color _color(_Categoria c) => switch (c) {
        _Categoria.viaje => ColoresApp.azul,
        _Categoria.pago => ColoresApp.verde,
        _Categoria.soporte => ColoresApp.naranja,
        _Categoria.grupo => const Color(0xFF00897B),
        _Categoria.sistema => ColoresApp.textoSecundario,
      };

  static IconData _iconForTipo(String? tipo) {
    switch (tipo) {
      case 'nuevo_viaje': return Icons.local_shipping_outlined;
      case 'viaje_aceptado': return Icons.check_circle_outline;
      case 'viaje_completado': return Icons.done_all;
      case 'viaje_cancelado': return Icons.cancel_outlined;
      case 'pago_recibido': return Icons.payments_outlined;
      case 'mensaje':
      case 'conversacion_mensaje':
        return Icons.chat_bubble_outline;
      case 'documentacion': return Icons.description_outlined;
      case 'disputa_cierre': return Icons.gavel_rounded;
      case 'suspension_por_pago': return Icons.money_off_rounded;
      case 'busqueda_sin_conductor': return Icons.search_off_rounded;
      case 'ticket_mensaje': return Icons.support_agent;
      case 'ticket_estado': return Icons.confirmation_number_outlined;
      default: return Icons.notifications_outlined;
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
      if (_error) {
        return ErrorCarga(titulo: 'No pudimos cargar tus notificaciones', onReintentar: _fetchNotifications);
      }
      return RefreshIndicator(
        onRefresh: _fetchNotifications,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 120),
            Icon(Icons.notifications_none, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text(
              'Sin notificaciones',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: ColoresApp.textoSecundario),
            ),
          ],
        ),
      );
    }
    // Encabezados de día (String) intercalados con los avisos (ya vienen
    // ordenados del más reciente al más antiguo).
    final items = <Object>[];
    String? ultimo;
    for (final n in _notifications) {
      final dia = _etiquetaDia(n['createdAt'] as String?);
      if (dia != ultimo) {
        items.add(dia);
        ultimo = dia;
      }
      items.add(n);
    }
    return RefreshIndicator(
      onRefresh: _fetchNotifications,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final it = items[i];
          if (it is String) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
              child: Text(it,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ColoresApp.textoSecundario)),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildNotifCard(it as Map<String, dynamic>),
          );
        },
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
                child: Text('Notificaciones',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              ),
              if (hayNoLeidas)
                Flexible(
                  child: TextButton(
                    onPressed: () => _service.markAllRead(),
                    child: const Text('Marcar todas como leídas', textAlign: TextAlign.center),
                  ),
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
    final color = _color(_categoria(tipo));
    final tarjeta = InkWell(
      onTap: () => _onNotifTap(notif),
      borderRadius: BorderRadius.circular(14),
      child: Opacity(
        opacity: leido ? 0.6 : 1,
        child: TarjetaBlanca(
          radio: 14,
          colorBorde: leido ? null : color.withValues(alpha: 0.35),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: Icon(_iconForTipo(tipo), color: color, size: 22),
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
                      Text(notif['mensaje'] as String,
                          style: const TextStyle(fontSize: 12, color: ColoresApp.textoSecundario),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis),
                    ],
                    const SizedBox(height: 4),
                    Text(_hora(notif['createdAt'] as String?),
                        style: const TextStyle(fontSize: 12, color: ColoresApp.textoSecundario)),
                  ],
                ),
              ),
              if (!leido)
                Container(
                  width: 9,
                  height: 9,
                  margin: const EdgeInsets.only(top: 4, left: 6),
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
            ],
          ),
        ),
      ),
    );
    if (leido) return tarjeta;
    // Deslizar marca como leída; la tarjeta se queda (atenuada) en su lugar.
    return Dismissible(
      key: ValueKey('notif_${notif['id']}'),
      direction: DismissDirection.horizontal,
      background: _fondoDeslizar(Alignment.centerLeft),
      secondaryBackground: _fondoDeslizar(Alignment.centerRight),
      confirmDismiss: (_) async {
        _service.markRead(notif);
        return false;
      },
      child: tarjeta,
    );
  }

  Widget _fondoDeslizar(Alignment alineacion) => Container(
        alignment: alineacion,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(color: ColoresApp.azulTenue, borderRadius: BorderRadius.circular(14)),
        child: const Icon(Icons.done_all, color: ColoresApp.azul),
      );

  void _onNotifTap(Map<String, dynamic> notif) {
    if (notif['leido'] != true) _service.markRead(notif);
    // Aviso de un ticket de soporte: abrir su detalle.
    final ticketId = notif['ticketId']?.toString();
    if (NotificationService.esTipoTicket(notif['tipo']?.toString()) && ticketId != null && ticketId.isNotEmpty) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => TicketDetalleScreen(ticketId: ticketId)));
      return;
    }
    // Aviso de un viaje: el mismo destino que al tocar el push (solo cliente).
    final viajeId = notif['viajeId']?.toString();
    if (viajeId != null && viajeId.isNotEmpty) _service.abrirViaje?.call(viajeId);
  }

  static DateTime? _local(String? iso) => iso == null ? null : DateTime.tryParse(iso)?.toLocal();

  static String _etiquetaDia(String? iso) {
    final dt = _local(iso);
    if (dt == null) return 'Antes';
    final hoy = DateTime.now();
    final dias = DateTime(hoy.year, hoy.month, hoy.day).difference(DateTime(dt.year, dt.month, dt.day)).inDays;
    if (dias <= 0) return 'Hoy';
    if (dias == 1) return 'Ayer';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  static String _hora(String? iso) {
    final dt = _local(iso);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    return '$h:${dt.minute.toString().padLeft(2, '0')} ${dt.hour < 12 ? 'a. m.' : 'p. m.'}';
  }
}
