import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api/chat_service.dart';
import '../../services/api_client.dart';
import '../../services/socket_service_client.dart';
import '../cliente/soporte_screen.dart' show ConversacionChatScreen;
import '../shared/soporte_contacto.dart';
import '../shared/tickets/acceso_tickets_soporte.dart';
import '../shared/ui_compartida.dart';

/// Soporte del conductor: tickets de soporte (Mis tickets / Nuevo ticket),
/// conversaciones con moderadores (portadas del cliente) y datos de contacto.
/// También la abre el diálogo de cuenta suspendida (sin sesión: se explica que
/// debe iniciar sesión y no se consultan las conversaciones).
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  List<Map<String, dynamic>> _conversaciones = [];
  bool _loading = true;
  String? _error;
  Timer? _debounce;
  StreamSubscription<Map<String, dynamic>>? _socketSub;

  bool get _conSesion => ApiClient.instance.token != null;

  @override
  void initState() {
    super.initState();
    if (_conSesion) {
      _socketSub = SocketServiceClient.instance.onConversationMessage.listen((_) => _refreshSoon());
      _fetch();
    }
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
      backgroundColor: ColoresApp.fondo,
      appBar: AppBar(
        backgroundColor: Colors.white, foregroundColor: ColoresApp.textoOscuro, elevation: 0,
        title: const Text('Soporte', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
      ),
      body: RefreshIndicator(
        onRefresh: () => _fetch(quiet: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            const AccesoTicketsSoporte(),
            // Sin sesión no hay conversaciones que consultar (cuenta suspendida).
            if (_conSesion) ...[
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Text('Conversaciones con moderadores', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: ColoresApp.textoOscuro)),
              ),
              ..._conversacionesWidgets(),
            ],
            const SizedBox(height: 20),
            const ContactoSoporteSection(),
          ],
        ),
      ),
    );
  }

  /// Solo el bloque de conversaciones cambia de estado; el resto de la pantalla
  /// se ve siempre (a diferencia del cliente, que tapa todo con el spinner).
  List<Widget> _conversacionesWidgets() {
    if (_loading) {
      return const [Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))];
    }
    if (_error != null) {
      return [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No se pudieron cargar las conversaciones', style: TextStyle(fontSize: 15, color: ColoresApp.textoOscuro)),
              const SizedBox(height: 4),
              Text(_error!, style: const TextStyle(fontSize: 13, color: ColoresApp.textoSecundario), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _fetch, child: const Text('Reintentar')),
            ],
          ),
        ),
      ];
    }
    if (_conversaciones.isEmpty) {
      return const [
        TarjetaBlanca(
          child: Column(
            children: [
              Icon(Icons.support_agent, size: 36, color: ColoresApp.chevron),
              SizedBox(height: 8),
              Text('No tienes conversaciones de soporte',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: ColoresApp.textoOscuro), textAlign: TextAlign.center),
              SizedBox(height: 4),
              Text('Si un moderador te escribe, la conversación aparecerá aquí',
                  style: TextStyle(fontSize: 13, color: ColoresApp.textoSecundario), textAlign: TextAlign.center),
            ],
          ),
        ),
      ];
    }
    return [
      for (final c in _conversaciones) Padding(padding: const EdgeInsets.only(bottom: 10), child: _buildTile(c)),
    ];
  }

  Widget _buildTile(Map<String, dynamic> c) {
    final moderador = c['moderador'] as String?;
    final nombre = moderador ?? 'Soporte';
    final ultimo = c['ultimoMensaje'] as String?;
    final noLeidos = (c['noLeidos'] as num?)?.toInt() ?? 0;
    final viaje = c['viaje'] as Map<String, dynamic>?;
    final subtitulo = viaje != null
        ? '${viaje['origenDireccion'] ?? ''} → ${viaje['destinoDireccion'] ?? ''}'
        : (ultimo ?? 'Toca para chatear con soporte');

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: ColoresApp.borde)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: ColoresApp.azulTenue, borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.chat_bubble_outline, size: 20, color: ColoresApp.azul),
        ),
        title: Row(
          children: [
            Expanded(child: Text(nombre, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: ColoresApp.textoOscuro))),
            if (noLeidos > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: ColoresApp.azulTenue, borderRadius: BorderRadius.circular(8)),
                child: Text('$noLeidos', style: const TextStyle(color: ColoresApp.azul, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
          ],
        ),
        subtitle: Text(
          subtitulo,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, color: ColoresApp.textoSecundario),
        ),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ConversacionChatScreen(conversacionId: c['id'], titulo: nombre),
            ),
          );
          if (mounted) _fetch(quiet: true);
        },
      ),
    );
  }
}
