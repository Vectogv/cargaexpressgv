import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../models/ticket_soporte.dart';
import '../../../services/api/http_client.dart' show ApiException;
import '../../../services/api/ticket_service.dart';
import '../../../services/api/trip_service.dart';
import '../../../widgets/error_carga.dart' show mensajeDeError;
import '../ui_compartida.dart';
import 'ticket_detalle_screen.dart';
import 'tickets_ui.dart';

/// Formulario "Nuevo ticket": categoría, asunto, descripción, viaje opcional
/// (preseleccionado si se abre desde un viaje) y foto opcional. Al crearlo
/// abre el detalle del ticket.
class NuevoTicketScreen extends StatefulWidget {
  /// Viaje relacionado (`Trip.toJson()` o el mapa del backend), opcional.
  final Map<String, dynamic>? viaje;
  final String? categoriaInicial;
  final String? asuntoInicial;
  final String? descripcionInicial;

  const NuevoTicketScreen({
    super.key,
    this.viaje,
    this.categoriaInicial,
    this.asuntoInicial,
    this.descripcionInicial,
  });

  @override
  State<NuevoTicketScreen> createState() => _NuevoTicketScreenState();
}

class _NuevoTicketScreenState extends State<NuevoTicketScreen> {
  static const int _asuntoMin = 3;
  static const int _asuntoMax = 150;
  static const int _descripcionMin = 10;
  static const int _descripcionMax = 2000;

  late String _categoria;
  late final TextEditingController _asuntoCtrl;
  late final TextEditingController _descripcionCtrl;
  Map<String, dynamic>? _viaje;
  Uint8List? _foto;
  String? _fotoNombre;
  bool _enviando = false;
  bool _cargandoViajes = false;

  @override
  void initState() {
    super.initState();
    _viaje = widget.viaje;
    final inicial = widget.categoriaInicial;
    _categoria = (inicial != null && TicketSoporte.categorias.contains(inicial))
        ? inicial
        : (_viaje != null ? 'viaje' : 'otro');
    _asuntoCtrl = TextEditingController(text: widget.asuntoInicial ?? '');
    _descripcionCtrl = TextEditingController(text: widget.descripcionInicial ?? '');
  }

  @override
  void dispose() {
    _asuntoCtrl.dispose();
    _descripcionCtrl.dispose();
    super.dispose();
  }

  void _snack(String texto) {
    if (!mounted) return;
    // Un aviso reemplaza al anterior (los de validación no deben encolarse).
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
      final picked = await ImagePicker().pickImage(
        source: origen,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 75,
      );
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

  /// Últimos viajes del usuario (cliente o conductor) para asociar uno.
  Future<void> _elegirViaje() async {
    if (_cargandoViajes) return;
    setState(() => _cargandoViajes = true);
    List<Map<String, dynamic>> viajes;
    try {
      viajes = await TripService.getTripHistory(limit: 10);
    } catch (e) {
      if (mounted) setState(() => _cargandoViajes = false);
      _snack('No se pudieron cargar tus viajes: ${mensajeDeError(e)}');
      return;
    }
    if (!mounted) return;
    setState(() => _cargandoViajes = false);
    if (viajes.isEmpty) {
      _snack('Aún no tienes viajes para asociar.');
      return;
    }
    final elegido = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Elige el viaje', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final v in viajes)
                    ListTile(
                      key: Key('viaje_opcion_${idDeViajeTicket(v) ?? ''}'),
                      leading: const Icon(Icons.local_shipping_outlined, color: ColoresApp.azul),
                      title: Text(
                        rutaDeViajeTicket(v).isEmpty ? 'Viaje #${idDeViajeTicket(v) ?? ''}' : rutaDeViajeTicket(v),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text('#${idDeViajeTicket(v) ?? ''} · ${v['estado'] ?? ''}'),
                      onTap: () => Navigator.pop(ctx, v),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (elegido != null && mounted) setState(() => _viaje = elegido);
  }

  String? _validar() {
    final asunto = _asuntoCtrl.text.trim();
    final descripcion = _descripcionCtrl.text.trim();
    if (asunto.length < _asuntoMin) return 'Escribe un asunto (mínimo $_asuntoMin letras).';
    if (asunto.length > _asuntoMax) return 'El asunto es muy largo (máximo $_asuntoMax caracteres).';
    if (descripcion.length < _descripcionMin) return 'Describe el problema con un poco más de detalle (mínimo $_descripcionMin letras).';
    if (descripcion.length > _descripcionMax) return 'La descripción es muy larga (máximo $_descripcionMax caracteres).';
    return null;
  }

  Future<void> _enviar() async {
    if (_enviando) return;
    final error = _validar();
    if (error != null) {
      _snack(error);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _enviando = true);
    try {
      final ticket = await TicketService.crear(
        categoria: _categoria,
        asunto: _asuntoCtrl.text.trim(),
        descripcion: _descripcionCtrl.text.trim(),
        viajeId: idDeViajeTicket(_viaje),
        imagenBytes: _foto,
        imagenNombre: _fotoNombre,
      );
      if (!mounted) return;
      _snack('Ticket #${ticket.id} creado. Te avisaremos cuando respondan.');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => TicketDetalleScreen(ticketId: ticket.id, inicial: ticket)),
      );
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack('No se pudo crear el ticket: ${mensajeDeError(e)}');
    } finally {
      if (mounted) setState(() => _enviando = false);
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
        title: const Text('Nuevo ticket', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const EncabezadoEstado(
                titulo: '¿En qué te ayudamos?',
                detalle: 'Cuéntanos qué pasó y te respondemos por aquí. Te avisamos con una notificación.',
                icono: Icons.headset_mic_outlined,
              ),
              const SizedBox(height: 14),
              _seccion('Categoría', _buildCategorias()),
              const SizedBox(height: 12),
              _seccion(
                'Asunto',
                TextField(
                  key: const Key('campo_asunto'),
                  controller: _asuntoCtrl,
                  maxLength: _asuntoMax,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _decoracion('Ej.: Cobro duplicado en un viaje'),
                ),
              ),
              const SizedBox(height: 12),
              _seccion(
                'Descripción',
                TextField(
                  key: const Key('campo_descripcion'),
                  controller: _descripcionCtrl,
                  maxLength: _descripcionMax,
                  minLines: 4,
                  maxLines: 8,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _decoracion('Describe lo que ocurrió con el mayor detalle posible...'),
                ),
              ),
              const SizedBox(height: 12),
              _seccion('Viaje relacionado (opcional)', _buildViaje()),
              const SizedBox(height: 12),
              _seccion('Foto (opcional)', _buildFoto()),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BarraInferiorFija(
        child: BotonPrincipal(
          key: const Key('btn_enviar_ticket'),
          texto: 'Enviar ticket',
          icono: Icons.send_rounded,
          cargando: _enviando,
          onPressed: _enviar,
        ),
      ),
    );
  }

  InputDecoration _decoracion(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: ColoresApp.borde),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: ColoresApp.azul, width: 1.5),
      ),
    );
  }

  Widget _seccion(String titulo, Widget child) {
    return TarjetaBlanca(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ColoresApp.textoSecundario)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildCategorias() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in TicketSoporte.categorias)
          ChoiceChip(
            key: Key('categoria_$c'),
            avatar: Icon(
              iconoCategoriaTicket(c),
              size: 16,
              color: _categoria == c ? Colors.white : ColoresApp.textoSecundario,
            ),
            label: Text(TicketSoporte.etiquetaCategoria(c)),
            selected: _categoria == c,
            onSelected: (_) => setState(() => _categoria = c),
            selectedColor: ColoresApp.azul,
            backgroundColor: Colors.white,
            showCheckmark: false,
            side: BorderSide(color: _categoria == c ? ColoresApp.azul : ColoresApp.borde),
            labelStyle: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _categoria == c ? Colors.white : ColoresApp.textoOscuro,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
      ],
    );
  }

  Widget _buildViaje() {
    final v = _viaje;
    if (v != null) {
      return Row(
        children: [
          const Icon(Icons.local_shipping_outlined, color: ColoresApp.azul, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              resumenViajeTicket(v),
              key: const Key('viaje_seleccionado'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: ColoresApp.textoOscuro),
            ),
          ),
          IconButton(
            key: const Key('btn_quitar_viaje'),
            tooltip: 'Quitar viaje',
            onPressed: () => setState(() => _viaje = null),
            icon: const Icon(Icons.close, size: 20, color: ColoresApp.textoSecundario),
          ),
        ],
      );
    }
    return OutlinedButton.icon(
      key: const Key('btn_asociar_viaje'),
      onPressed: _cargandoViajes ? null : _elegirViaje,
      icon: _cargandoViajes
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.add_road_outlined, size: 20),
      label: const Text('Asociar un viaje'),
      style: OutlinedButton.styleFrom(
        foregroundColor: ColoresApp.textoOscuro,
        side: const BorderSide(color: ColoresApp.borde),
        minimumSize: const Size.fromHeight(46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildFoto() {
    final foto = _foto;
    if (foto != null) {
      return Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.memory(
              foto,
              key: const Key('foto_seleccionada'),
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              cacheWidth: 240,
              errorBuilder: (_, _, _) => const SizedBox(
                width: 80,
                height: 80,
                child: Icon(Icons.broken_image, color: ColoresApp.textoSecundario),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Se enviará junto con el ticket.', style: TextStyle(fontSize: 13, color: ColoresApp.textoSecundario)),
          ),
          IconButton(
            key: const Key('btn_quitar_foto'),
            tooltip: 'Quitar foto',
            onPressed: () => setState(() {
              _foto = null;
              _fotoNombre = null;
            }),
            icon: const Icon(Icons.delete_outline, color: ColoresApp.rojo),
          ),
        ],
      );
    }
    return OutlinedButton.icon(
      key: const Key('btn_agregar_foto'),
      onPressed: _elegirFoto,
      icon: const Icon(Icons.add_a_photo_outlined, size: 20),
      label: const Text('Agregar una foto'),
      style: OutlinedButton.styleFrom(
        foregroundColor: ColoresApp.textoOscuro,
        side: const BorderSide(color: ColoresApp.borde),
        minimumSize: const Size.fromHeight(46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
