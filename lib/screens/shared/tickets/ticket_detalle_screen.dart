import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../models/ticket_soporte.dart';
import '../../../services/api/http_client.dart' show ApiException;
import '../../../services/api/ticket_service.dart';
import '../../../services/socket_service_client.dart';
import '../../../widgets/error_carga.dart';
import '../../../widgets/media_image.dart';
import '../ui_compartida.dart';
import 'nuevo_ticket_screen.dart';
import 'tickets_ui.dart';

/// Detalle de un ticket de soporte: hilo estilo chat (usuario a la derecha,
/// soporte a la izquierda con su nombre), adjuntos, caja para escribir con
/// foto y botón "Cerrar ticket". Cerrado, no se puede escribir.
///
/// Tiempo real: `ticket:mensaje` y `ticket:estado` por socket, más una
/// consulta de respaldo cada [intervaloRespaldo] mientras la pantalla está
/// abierta, al volver a la app y al reconectar el socket (en los celulares
/// el sistema corta el socket en segundo plano y la app lo cree conectado).
class TicketDetalleScreen extends StatefulWidget {
  final String ticketId;

  /// Datos ya conocidos (de la lista o del alta) para pintar sin esperar.
  final TicketSoporte? inicial;

  static const Duration intervaloRespaldo = Duration(seconds: 5);

  const TicketDetalleScreen({super.key, required this.ticketId, this.inicial});

  @override
  State<TicketDetalleScreen> createState() => _TicketDetalleScreenState();
}

class _TicketDetalleScreenState extends State<TicketDetalleScreen> with WidgetsBindingObserver {
  TicketSoporte? _ticket;
  bool _loading = true;
  String? _error;
  bool _enviando = false;
  bool _cerrando = false;
  bool _consultando = false;
  Uint8List? _foto;
  String? _fotoNombre;
  Timer? _respaldo;
  final List<StreamSubscription<dynamic>> _subs = [];
  final TextEditingController _mensajeCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  String get _id => widget.ticketId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticket = widget.inicial;
    final socket = SocketServiceClient.instance;
    _subs.add(socket.onTicketMensaje.listen(_onSocketMensaje));
    _subs.add(socket.onTicketEstado.listen(_onSocketEstado));
    _subs.add(socket.onConnection.listen((conectado) {
      if (conectado) _trasFrame(() => _cargar(quiet: true));
    }));
    _cargar();
    _respaldo = Timer.periodic(TicketDetalleScreen.intervaloRespaldo, (_) {
      if (mounted && !_enviando) _cargar(quiet: true);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _respaldo?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _mensajeCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _cargar(quiet: true);
  }

  /// Aplica un cambio llegado por socket fuera del build en curso y
  /// garantiza que haya un frame (ver rastreo_screen._trasFrame).
  void _trasFrame(VoidCallback fn) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) fn();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _onSocketMensaje(Map<String, dynamic> data) {
    if (data['ticketId']?.toString() != _id) return;
    final raw = data['mensaje'];
    if (raw is! Map) return;
    final mensaje = MensajeTicket.fromJson(Map<String, dynamic>.from(raw));
    final estado = data['estado']?.toString();
    _trasFrame(() {
      final t = _ticket;
      if (t == null) return;
      if (t.mensajes.any((m) => m.id == mensaje.id)) return;
      setState(() {
        _ticket = t.copyWith(
          mensajes: [...t.mensajes, mensaje],
          totalMensajes: t.totalMensajes + 1,
          ultimoMensajeAt: mensaje.createdAt ?? DateTime.now(),
          estado: estado,
        );
      });
      _scrollAbajo();
    });
  }

  void _onSocketEstado(Map<String, dynamic> data) {
    if ((data['id'] ?? data['ticketId'])?.toString() != _id) return;
    final estado = data['estado']?.toString();
    final moderador = data['moderador'];
    _trasFrame(() {
      final t = _ticket;
      if (t == null) return;
      setState(() {
        _ticket = t.copyWith(
          estado: estado,
          moderadorNombre: moderador is Map ? moderador['nombre']?.toString() : null,
        );
      });
    });
  }

  Future<void> _cargar({bool quiet = false}) async {
    if (_consultando) return;
    _consultando = true;
    if (!quiet && mounted && _ticket == null) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final nuevo = await TicketService.detalle(_id);
      if (!mounted) return;
      final anterior = _ticket;
      // Los mensajes que aún se están enviando (o fallaron) no están en el
      // backend: se conservan al final para no perderlos de la vista.
      final pendientes = anterior?.mensajes.where((m) => m.estadoLocal != null).toList() ?? const <MensajeTicket>[];
      final cambio = anterior == null ||
          anterior.mensajes.length != nuevo.mensajes.length ||
          anterior.estado != nuevo.estado;
      setState(() {
        _ticket = pendientes.isEmpty ? nuevo : nuevo.copyWith(mensajes: [...nuevo.mensajes, ...pendientes]);
        _loading = false;
        _error = null;
      });
      if (cambio) _scrollAbajo();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_ticket == null || !quiet) _error = mensajeDeError(e);
      });
    } finally {
      _consultando = false;
    }
  }

  void _scrollAbajo() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  void _snack(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _elegirFoto() async {
    final origen = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tomar una foto'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (origen == null || !mounted) return;
    try {
      final picked = await ImagePicker().pickImage(source: origen, maxWidth: 1600, maxHeight: 1600, imageQuality: 75);
      if (picked == null || !mounted) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _foto = bytes;
        _fotoNombre = 'ticket_${DateTime.now().millisecondsSinceEpoch}.jpg';
      });
    } catch (e) {
      _snack('No se pudo abrir la foto: ${mensajeDeError(e)}');
    }
  }

  Future<void> _enviar() async {
    final t = _ticket;
    if (t == null || t.cerrado || _enviando) return;
    var texto = _mensajeCtrl.text.trim();
    final foto = _foto;
    final fotoNombre = _fotoNombre;
    if (texto.isEmpty && foto == null) return;
    if (texto.isEmpty) texto = 'Adjunto una imagen.';
    if (texto.length > 2000) {
      _snack('El mensaje es muy largo (máximo 2000 caracteres).');
      return;
    }
    final tempId = 'local_${DateTime.now().microsecondsSinceEpoch}';
    final pendiente = MensajeTicket(
      id: tempId,
      rolAutor: 'usuario',
      mensaje: texto,
      createdAt: DateTime.now(),
      estadoLocal: 'sending',
    );
    setState(() {
      _enviando = true;
      _mensajeCtrl.clear();
      _foto = null;
      _fotoNombre = null;
      _ticket = t.copyWith(mensajes: [...t.mensajes, pendiente]);
    });
    _scrollAbajo();
    try {
      final r = await TicketService.enviarMensaje(_id, mensaje: texto, imagenBytes: foto, imagenNombre: fotoNombre);
      if (!mounted) return;
      setState(() {
        final actual = _ticket ?? t;
        final lista = actual.mensajes.where((m) => m.id != tempId && m.id != r.mensaje.id).toList()..add(r.mensaje);
        _ticket = actual.copyWith(
          mensajes: lista,
          totalMensajes: actual.totalMensajes + 1,
          ultimoMensajeAt: r.mensaje.createdAt ?? DateTime.now(),
          estado: r.ticketEstado,
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        final actual = _ticket ?? t;
        _ticket = actual.copyWith(
          mensajes: [
            for (final m in actual.mensajes) m.id == tempId ? m.copyWith(estadoLocal: 'failed') : m,
          ],
        );
      });
      final msg = e is ApiException ? e.message : mensajeDeError(e);
      _snack('No se pudo enviar: $msg');
      // 422: el ticket pudo cerrarse mientras escribía; se refresca el estado.
      if (e is ApiException && e.statusCode == 422) unawaited(_cargar(quiet: true));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _cerrarTicket() async {
    final t = _ticket;
    if (t == null || t.cerrado || _cerrando) return;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Cerrar ticket'),
        content: const Text('Una vez cerrado no podrás escribir más en este ticket. Si vuelves a necesitar ayuda, podrás abrir uno nuevo.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Volver')),
          FilledButton(
            key: const Key('btn_confirmar_cerrar_ticket'),
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: ColoresApp.rojo),
            child: const Text('Cerrar ticket'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    setState(() => _cerrando = true);
    try {
      final cerrado = await TicketService.cerrar(_id);
      if (!mounted) return;
      setState(() => _ticket = cerrado.copyWith(mensajes: cerrado.mensajes.isEmpty ? t.mensajes : cerrado.mensajes));
      _snack('Ticket cerrado.');
    } on ApiException catch (e) {
      _snack(e.message);
      unawaited(_cargar(quiet: true));
    } catch (e) {
      _snack('No se pudo cerrar el ticket: ${mensajeDeError(e)}');
    } finally {
      if (mounted) setState(() => _cerrando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _ticket;
    return Scaffold(
      backgroundColor: ColoresApp.fondo,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: ColoresApp.textoOscuro,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ticket #$_id', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            if (t != null)
              Text(
                TicketSoporte.etiquetaEstado(t.estado),
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: colorEstadoTicket(t.estado)),
              ),
          ],
        ),
        actions: [
          if (t != null && !t.cerrado)
            TextButton(
              key: const Key('btn_cerrar_ticket'),
              onPressed: _cerrando ? null : _cerrarTicket,
              style: TextButton.styleFrom(foregroundColor: ColoresApp.rojo),
              child: _cerrando
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Cerrar ticket', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: _buildCuerpo(t),
      bottomNavigationBar: t == null ? null : _buildBarraInferior(t),
    );
  }

  Widget _buildCuerpo(TicketSoporte? t) {
    if (t == null) {
      if (_loading) return const Center(child: CircularProgressIndicator());
      return ErrorCarga(
        titulo: 'No pudimos cargar el ticket',
        detalle: _error,
        onReintentar: _cargar,
      );
    }
    return ListView(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        _buildCabecera(t),
        if (t.moderadorNombre != null) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.support_agent, size: 16, color: ColoresApp.textoSecundario),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Te atiende: ${t.moderadorNombre}',
                  style: const TextStyle(fontSize: 12.5, color: ColoresApp.textoSecundario, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        if (t.mensajes.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text(
              'Recibimos tu ticket. Soporte te responderá por aquí.',
              key: Key('ticket_sin_mensajes'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: ColoresApp.textoSecundario),
            ),
          ),
        for (final m in t.mensajes) _Burbuja(mensaje: m, onVerAdjunto: _verAdjunto),
        if (t.cerrado) ...[
          const SizedBox(height: 8),
          Container(
            key: const Key('aviso_ticket_cerrado'),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_outline, size: 18, color: ColoresApp.textoSecundario),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Este ticket está cerrado${t.cerradoAt != null ? ' desde el ${fechaCortaTicket(t.cerradoAt!)}' : ''}. '
                    'Si necesitas algo más, abre uno nuevo.',
                    style: const TextStyle(fontSize: 12.5, color: ColoresApp.textoSecundario, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCabecera(TicketSoporte t) {
    return TarjetaBlanca(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ChipEstadoTicket(estado: t.estado),
              const SizedBox(width: 8),
              Icon(iconoCategoriaTicket(t.categoria), size: 15, color: ColoresApp.textoSecundario),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  TicketSoporte.etiquetaCategoria(t.categoria),
                  style: const TextStyle(fontSize: 12.5, color: ColoresApp.textoSecundario),
                ),
              ),
              if (t.createdAt != null)
                Text(fechaCortaTicket(t.createdAt!), style: const TextStyle(fontSize: 12, color: ColoresApp.textoSecundario)),
            ],
          ),
          const SizedBox(height: 10),
          Text(t.asunto, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ColoresApp.textoOscuro)),
          if (t.viaje != null || t.viajeId != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.local_shipping_outlined, size: 16, color: ColoresApp.azul),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    t.viaje != null ? resumenViajeTicket(t.viaje) : 'Viaje #${t.viajeId}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, color: ColoresApp.textoSecundario, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Text(t.descripcion, style: const TextStyle(fontSize: 14, color: Color(0xFF374151), height: 1.45)),
          if (t.adjunto != null) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => _verAdjunto(t.adjunto!),
              child: MediaImage(path: t.adjunto, width: 160, height: 120, borderRadius: BorderRadius.circular(10)),
            ),
          ],
        ],
      ),
    );
  }

  void _verAdjunto(String path) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Center(child: MediaImage(path: path, fit: BoxFit.contain)),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarraInferior(TicketSoporte t) {
    if (t.cerrado) {
      return BarraInferiorFija(
        child: BotonSecundario(
          key: const Key('btn_nuevo_ticket_desde_cerrado'),
          texto: 'Abrir un ticket nuevo',
          icono: Icons.add,
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => NuevoTicketScreen(viaje: t.viaje, categoriaInicial: t.categoria)),
          ),
        ),
      );
    }
    final foto = _foto;
    return BarraInferiorFija(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (foto != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 8),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      foto,
                      key: const Key('foto_mensaje_seleccionada'),
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      cacheWidth: 168,
                      errorBuilder: (_, _, _) => const SizedBox(width: 56, height: 56, child: Icon(Icons.broken_image)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Foto lista para enviar', style: TextStyle(fontSize: 12.5, color: ColoresApp.textoSecundario)),
                  ),
                  IconButton(
                    key: const Key('btn_quitar_foto_mensaje'),
                    tooltip: 'Quitar foto',
                    onPressed: () => setState(() {
                      _foto = null;
                      _fotoNombre = null;
                    }),
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                key: const Key('btn_foto_mensaje'),
                tooltip: 'Adjuntar foto',
                onPressed: _enviando ? null : _elegirFoto,
                icon: const Icon(Icons.add_a_photo_outlined, color: ColoresApp.textoSecundario),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  decoration: BoxDecoration(color: ColoresApp.fondo, borderRadius: BorderRadius.circular(22)),
                  child: TextField(
                    key: const Key('campo_mensaje'),
                    controller: _mensajeCtrl,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Escribe un mensaje...',
                      hintStyle: TextStyle(color: ColoresApp.textoSecundario, fontSize: 14),
                      isDense: true,
                      border: InputBorder.none,
                    ),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 44,
                height: 44,
                child: IconButton.filled(
                  key: const Key('btn_enviar_mensaje'),
                  tooltip: 'Enviar',
                  onPressed: _enviando ? null : _enviar,
                  style: IconButton.styleFrom(backgroundColor: ColoresApp.azul, foregroundColor: Colors.white),
                  icon: _enviando
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Burbuja de un mensaje: usuario a la derecha (azul), soporte a la
/// izquierda (blanca) con el nombre de quien responde.
class _Burbuja extends StatelessWidget {
  final MensajeTicket mensaje;
  final void Function(String path) onVerAdjunto;
  const _Burbuja({required this.mensaje, required this.onVerAdjunto});

  @override
  Widget build(BuildContext context) {
    final m = mensaje;
    final mio = m.esDelUsuario;
    final estado = m.estadoLocal;
    final ancho = MediaQuery.sizeOf(context).width * 0.72;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: mio ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!mio) ...[
            MediaAvatar(
              path: m.autorAvatar,
              name: m.autorNombre,
              radius: 15,
              backgroundColor: ColoresApp.azulOscuro,
              foregroundColor: Colors.white,
              icon: Icons.support_agent,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: mio ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!mio)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 3),
                    child: Text(
                      m.nombreParaMostrar,
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: ColoresApp.textoSecundario),
                    ),
                  ),
                Container(
                  constraints: BoxConstraints(maxWidth: ancho),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: mio ? ColoresApp.azul : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(mio ? 16 : 4),
                      bottomRight: Radius.circular(mio ? 4 : 16),
                    ),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (m.adjunto != null) ...[
                        GestureDetector(
                          onTap: () => onVerAdjunto(m.adjunto!),
                          child: MediaImage(path: m.adjunto, width: 200, height: 150, borderRadius: BorderRadius.circular(10)),
                        ),
                        if (m.mensaje.isNotEmpty) const SizedBox(height: 8),
                      ],
                      if (m.mensaje.isNotEmpty)
                        Text(
                          m.mensaje,
                          style: TextStyle(color: mio ? Colors.white : ColoresApp.textoOscuro, fontSize: 14, height: 1.4),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(horaMensajeTicket(m.createdAt), style: const TextStyle(fontSize: 10.5, color: ColoresApp.textoSecundario)),
                    if (mio) ...[
                      const SizedBox(width: 4),
                      Icon(
                        estado == 'failed'
                            ? Icons.error_outline
                            : estado == 'sending'
                                ? Icons.access_time
                                : Icons.done,
                        size: 13,
                        color: estado == 'failed' ? ColoresApp.rojo : ColoresApp.textoSecundario,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
