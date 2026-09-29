import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api/chat_service.dart';
import '../../services/socket_service_client.dart';
import '../shared/soporte_contacto.dart';
import '../shared/tickets/acceso_tickets_soporte.dart';
import '../shared/ui_compartida.dart';
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
      backgroundColor: ColoresApp.fondo,
      appBar: AppBar(
        backgroundColor: ColoresApp.fondo,
        surfaceTintColor: ColoresApp.fondo,
        foregroundColor: ColoresApp.textoOscuro,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 16,
        automaticallyImplyLeading: Navigator.canPop(context),
        title: const Text('Soporte', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final List<Widget> conversaciones;
    if (_error != null) {
      conversaciones = [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No se pudo cargar el soporte', style: TextStyle(fontSize: 15, color: ColoresApp.textoOscuro)),
              const SizedBox(height: 4),
              Text(_error!, style: const TextStyle(fontSize: 13, color: ColoresApp.textoSecundario), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _fetch, child: const Text('Reintentar')),
            ],
          ),
        ),
      ];
    } else if (_conversaciones.isEmpty) {
      conversaciones = const [
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
    } else {
      conversaciones = [
        for (final c in _conversaciones) Padding(padding: const EdgeInsets.only(bottom: 10), child: _buildTile(c)),
      ];
    }
    // Tickets y conversaciones arriba (lo que más se usa); aviso SOS,
    // preguntas frecuentes y contacto al final.
    return RefreshIndicator(
      onRefresh: () => _fetch(quiet: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          const Text('Escríbenos por aquí y te respondemos en la app.', style: TextStyle(fontSize: 14, color: ColoresApp.textoSecundario)),
          const SizedBox(height: 16),
          const AccesoTicketsSoporte(),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text('Conversaciones con moderadores', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: ColoresApp.textoOscuro)),
          ),
          ...conversaciones,
          const SizedBox(height: 10),
          const _AvisoSos(),
          const SizedBox(height: 20),
          const _PreguntasFrecuentes(),
          const SizedBox(height: 20),
          const ContactoSoporteSection(),
        ],
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
class _AvisoSos extends StatelessWidget {
  const _AvisoSos();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: ColoresApp.naranjaFondo,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColoresApp.naranjaBorde),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, size: 20, color: ColoresApp.naranjaTexto),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('¿Una emergencia durante el viaje?',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ColoresApp.naranjaAviso)),
                SizedBox(height: 2),
                Text('Usa el botón SOS del mapa de rastreo. Avisa de inmediato al equipo de CargaExpress.',
                    style: TextStyle(fontSize: 13, color: ColoresApp.naranjaAviso)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreguntasFrecuentes extends StatelessWidget {
  const _PreguntasFrecuentes();

  static const _preguntas = [
    ('¿Qué es el PIN de entrega?',
        'Un código de 4 números que confirma que recibiste la carga. Dáselo al conductor solo cuando la tengas en tus manos.'),
    ('¿Puedo cancelar un envío?', 'Sí, mientras el conductor esté a más de 1 km del punto de recogida.'),
    ('¿Cómo se define el precio?', 'Tú propones un precio, los conductores ofertan y pagas el de la oferta que aceptes.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Preguntas frecuentes',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: ColoresApp.textoOscuro)),
        const SizedBox(height: 10),
        Material(
          color: Colors.white,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: ColoresApp.borde)),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: Column(
              children: [
                for (var i = 0; i < _preguntas.length; i++) ...[
                  if (i > 0) const Divider(height: 1, thickness: 1, color: ColoresApp.divisor),
                  ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    expandedAlignment: Alignment.centerLeft,
                    iconColor: ColoresApp.chevron,
                    collapsedIconColor: ColoresApp.chevron,
                    title: Text(_preguntas[i].$1,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: ColoresApp.textoOscuro)),
                    children: [
                      Text(_preguntas[i].$2, style: const TextStyle(fontSize: 14, color: ColoresApp.textoSecundario)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
