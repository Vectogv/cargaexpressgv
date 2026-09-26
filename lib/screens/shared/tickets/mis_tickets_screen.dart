import 'dart:async';

import 'package:flutter/material.dart';

import '../../../models/ticket_soporte.dart';
import '../../../services/api/ticket_service.dart';
import '../../../services/socket_service_client.dart';
import '../../../widgets/error_carga.dart';
import '../ui_compartida.dart';
import 'nuevo_ticket_screen.dart';
import 'ticket_detalle_screen.dart';
import 'tickets_ui.dart';

/// "Mis tickets" de soporte (cliente y conductor): lista con estado, asunto,
/// categoría, última actividad y cantidad de mensajes; filtros Activos /
/// Cerrados y botón para abrir uno nuevo.
class MisTicketsScreen extends StatefulWidget {
  const MisTicketsScreen({super.key});

  @override
  State<MisTicketsScreen> createState() => _MisTicketsScreenState();
}

class _MisTicketsScreenState extends State<MisTicketsScreen> with WidgetsBindingObserver {
  List<TicketSoporte> _tickets = [];
  bool _cerrados = false;
  bool _loading = true;
  String? _error;
  Timer? _debounce;
  final List<StreamSubscription<dynamic>> _subs = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final socket = SocketServiceClient.instance;
    _subs.add(socket.onTicketMensaje.listen((_) => _refrescarPronto()));
    _subs.add(socket.onTicketEstado.listen((_) => _refrescarPronto()));
    // Al reconectar (o al volver del segundo plano) se trae lo que el socket
    // se perdió mientras estaba cortado.
    _subs.add(socket.onConnection.listen((conectado) {
      if (conectado) _refrescarPronto();
    }));
    _cargar();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _cargar(quiet: true);
  }

  /// Aplica un cambio llegado por socket fuera del build en curso y
  /// garantiza que haya un frame (ver rastreo_screen._trasFrame).
  void _trasFrame(VoidCallback fn) {
    WidgetsBinding.instance.addPostFrameCallback((_) => fn());
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _refrescarPronto() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _trasFrame(() {
        if (mounted) _cargar(quiet: true);
      });
    });
  }

  Future<void> _cargar({bool quiet = false}) async {
    if (!quiet && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final r = await TicketService.listar(
        estados: _cerrados ? const ['cerrado'] : TicketSoporte.estadosActivos,
        limit: 50,
      );
      if (!mounted) return;
      setState(() {
        _tickets = r.tickets;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = mensajeDeError(e);
      });
    }
  }

  void _cambiarFiltro(bool cerrados) {
    if (_cerrados == cerrados) return;
    setState(() {
      _cerrados = cerrados;
      _tickets = [];
    });
    _cargar();
  }

  Future<void> _abrirDetalle(TicketSoporte t) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TicketDetalleScreen(ticketId: t.id, inicial: t)),
    );
    if (mounted) _cargar(quiet: true);
  }

  Future<void> _nuevoTicket() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const NuevoTicketScreen()));
    if (mounted) {
      // El ticket nuevo es activo: se muestra ese filtro.
      if (_cerrados) {
        setState(() => _cerrados = false);
      }
      _cargar(quiet: _tickets.isNotEmpty);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColoresApp.fondo,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: ColoresApp.textoOscuro,
        elevation: 0,
        title: const Text('Mis tickets', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          _buildFiltros(),
          Expanded(child: _buildCuerpo()),
        ],
      ),
      bottomNavigationBar: BarraInferiorFija(
        child: BotonPrincipal(
          key: const Key('btn_nuevo_ticket'),
          texto: 'Nuevo ticket',
          icono: Icons.add,
          onPressed: _nuevoTicket,
        ),
      ),
    );
  }

  Widget _buildFiltros() {
    Widget chip(String texto, bool cerrados, Key key) {
      final activo = _cerrados == cerrados;
      return ChoiceChip(
        key: key,
        label: Text(texto),
        selected: activo,
        onSelected: (_) => _cambiarFiltro(cerrados),
        selectedColor: ColoresApp.azul,
        backgroundColor: Colors.white,
        side: BorderSide(color: activo ? ColoresApp.azul : ColoresApp.borde),
        labelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: activo ? Colors.white : ColoresApp.textoOscuro,
        ),
        showCheckmark: false,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          chip('Activos', false, const Key('filtro_activos')),
          const SizedBox(width: 8),
          chip('Cerrados', true, const Key('filtro_cerrados')),
        ],
      ),
    );
  }

  Widget _buildCuerpo() {
    if (_loading && _tickets.isEmpty) return const Center(child: CircularProgressIndicator());
    if (_error != null && _tickets.isEmpty) {
      return ErrorCarga(
        titulo: 'No pudimos cargar tus tickets',
        detalle: _error,
        onReintentar: _cargar,
      );
    }
    if (_tickets.isEmpty) return _buildVacio();
    return RefreshIndicator(
      onRefresh: () => _cargar(quiet: true),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        itemCount: _tickets.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _TicketTile(ticket: _tickets[i], onTap: () => _abrirDetalle(_tickets[i])),
      ),
    );
  }

  Widget _buildVacio() {
    return RefreshIndicator(
      onRefresh: () => _cargar(quiet: true),
      child: ListView(
        key: const Key('tickets_vacio'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 48),
          Container(
            width: 84,
            height: 84,
            decoration: const BoxDecoration(color: Color(0xFFEFF6FF), shape: BoxShape.circle),
            child: const Icon(Icons.support_agent, size: 42, color: ColoresApp.azul),
          ),
          const SizedBox(height: 18),
          Text(
            _cerrados ? 'No tienes tickets cerrados' : 'Aún no tienes tickets',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: ColoresApp.textoOscuro),
          ),
          const SizedBox(height: 8),
          Text(
            _cerrados
                ? 'Cuando cierres un ticket o soporte lo dé por terminado, aparecerá aquí.'
                : 'Si tienes un problema con un pago, un viaje, tu cuenta o la app, abre un ticket y te respondemos lo antes posible.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13.5, color: ColoresApp.textoSecundario, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _TicketTile extends StatelessWidget {
  final TicketSoporte ticket;
  final VoidCallback onTap;
  const _TicketTile({required this.ticket, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = ticket;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('ticket_${t.id}'),
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: TarjetaBlanca(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ChipEstadoTicket(estado: t.estado),
                  const Spacer(),
                  Text(
                    tiempoRelativoTicket(t.ultimaActividad),
                    style: const TextStyle(fontSize: 12, color: ColoresApp.textoSecundario),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                t.asunto,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ColoresApp.textoOscuro),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(iconoCategoriaTicket(t.categoria), size: 15, color: ColoresApp.textoSecundario),
                  const SizedBox(width: 4),
                  Text(
                    '${TicketSoporte.etiquetaCategoria(t.categoria)} · #${t.id}',
                    style: const TextStyle(fontSize: 12.5, color: ColoresApp.textoSecundario),
                  ),
                  const Spacer(),
                  const Icon(Icons.chat_bubble_outline, size: 15, color: ColoresApp.textoSecundario),
                  const SizedBox(width: 4),
                  Text(
                    '${t.totalMensajes}',
                    key: Key('ticket_${t.id}_mensajes'),
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: ColoresApp.textoSecundario),
                  ),
                ],
              ),
              if (t.moderadorNombre != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Te atiende: ${t.moderadorNombre}',
                  style: const TextStyle(fontSize: 12, color: ColoresApp.textoSecundario),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
