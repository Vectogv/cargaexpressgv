import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api/chat_service.dart';
import '../../services/socket_service_client.dart';
import '../shared/soporte_contacto.dart';
import '../shared/tickets/acceso_tickets_soporte.dart';
import 'chat_thread_screen.dart';

class SoporteScreen extends StatefulWidget {
  const SoporteScreen({super.key});

  @override
  State<SoporteScreen> createState() => _SoporteScreenState();
}

class _SoporteScreenState extends State<SoporteScreen> {
  List<Map<String, dynamic>> _conversaciones = [];
  bool _loading = true;
  String? _error;
  Timer? _debounce;
  StreamSubscription<Map<String, dynamic>>? _socketSub;

  static const Color _bgLight = Color(0xFFF5F7FA);
  static const Color _white = Colors.white;

  @override
  void initState() {
    super.initState();
    _socketSub = SocketServiceClient.instance.onConversationMessage.listen((_) => _refreshSoon());
    _fetch();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _socketSub?.cancel();
    super.dispose();
  }

  void _refreshSoon() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) _fetch(quiet: true);
    });
  }

  Future<void> _fetch({bool quiet = false}) async {
    if (!quiet) setState(() { _loading = true; _error = null; });
    try {
      final lista = await ChatService.getConversations();
      if (mounted) {
        setState(() {
          _conversaciones = lista;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        backgroundColor: _white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Color(0xFF1A1A2E)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Soporte', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
      ),
      body: _buildBody(),
    );
  }

  /// Tickets de soporte arriba (siempre, con o sin conversaciones) y debajo
  /// las conversaciones que abre un moderador con el cliente.
  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final cabecera = <Widget>[
      const AccesoTicketsSoporte(),
      const SizedBox(height: 16),
      const ContactoSoporteSection(),
      const SizedBox(height: 20),
      const Padding(
        padding: EdgeInsets.only(left: 4, bottom: 8),
        child: Text('Conversaciones con moderadores', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF757575))),
      ),
    ];
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ...cabecera,
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('No se pudo cargar el soporte', style: TextStyle(fontSize: 15, color: Colors.black54)),
                const SizedBox(height: 4),
                Text(_error!, style: const TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(onPressed: _fetch, child: const Text('Reintentar')),
              ],
            ),
          ),
        ],
      );
    }
    if (_conversaciones.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetch,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            ...cabecera,
            const SizedBox(height: 24),
            const Icon(Icons.support_agent, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Center(child: Text('No tienes conversaciones de soporte', style: TextStyle(fontSize: 15, color: Colors.black45), textAlign: TextAlign.center)),
            const SizedBox(height: 4),
            Center(child: Text('Si un moderador te escribe, la conversaci\u00f3n aparecer\u00e1 aqu\u00ed', style: TextStyle(fontSize: 12, color: Colors.grey.shade400), textAlign: TextAlign.center)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _fetch(quiet: true),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _conversaciones.length + 1,
        separatorBuilder: (_, i) => SizedBox(height: i == 0 ? 0 : 10),
        itemBuilder: (_, i) {
          if (i == 0) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: cabecera);
          final c = _conversaciones[i - 1];
          return _buildTile(c);
        },
      ),
    );
  }

  Widget _buildTile(Map<String, dynamic> c) {
    final moderador = c['moderador'] as String?;
    final nombre = moderador ?? 'Soporte';
    final ultimo = c['ultimoMensaje'] as String?;
    final noLeidos = (c['noLeidos'] as num?)?.toInt() ?? 0;
    final viaje = c['viaje'] as Map<String, dynamic>?;
    final subtitulo = viaje != null
        ? '${viaje['origenDireccion'] ?? ''} \u2192 ${viaje['destinoDireccion'] ?? ''}'
        : (ultimo ?? 'Toca para chatear con soporte');

    return Material(
      color: _white,
      borderRadius: BorderRadius.circular(14),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF1A3C6E).withValues(alpha: 0.1),
          child: const Icon(Icons.support_agent, color: Color(0xFF1A3C6E)),
        ),
        title: Row(
          children: [
            Expanded(child: Text(nombre, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
            if (noLeidos > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: const BoxDecoration(color: Color(0xFF4CAF50), shape: BoxShape.circle),
                child: Text('$noLeidos', style: const TextStyle(color: Colors.white, fontSize: 11)),
              ),
          ],
        ),
        subtitle: Text(
          subtitulo,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ConversacionChatScreen(
                conversacionId: c['id'],
                titulo: nombre,
              ),
            ),
          );
          if (mounted) _fetch(quiet: true);
        },
      ),
    );
  }
}

class ConversacionChatScreen extends StatelessWidget {
  final dynamic conversacionId;
  final String titulo;
  const ConversacionChatScreen({super.key, required this.conversacionId, required this.titulo});

  @override
  Widget build(BuildContext context) {
    final id = conversacionId.toString();
    return ChatThreadScreen(
      titulo: titulo,
      subtitulo: 'Soporte Carga Express',
      threadId: id,
      idField: 'conversacionId',
      fetchMensajes: () => ChatService.getConversationMessages(conversacionId),
      enviarMensaje: (texto) => ChatService.sendConversationMessage(conversacionId, texto),
      mensajesSocket: SocketServiceClient.instance.onConversationMessage,
    );
  }
}