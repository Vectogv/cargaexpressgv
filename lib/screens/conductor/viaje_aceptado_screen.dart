import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../widgets/mapa_viaje.dart';
import '../../widgets/media_image.dart';
import '../shared/ui_compartida.dart';

/// "Viaje aceptado": el cliente aceptó la oferta y el conductor debe ir al
/// punto de recogida. El mapa muestra la recogida (no el destino) y, si el
/// backend ya calculó la ruta hacia ella, la dibuja.
class ViajeAceptadoScreen extends StatelessWidget {
  final String nombreCliente;
  final double ratingCliente;
  final String? avatarUrl;
  final String origen;
  final String destino;
  final String precioAcordado;
  final bool isStarting;
  final bool isCancelling;
  final VoidCallback? onLlamar;
  final VoidCallback? onMensaje;

  /// Acción principal de esta fase: avisar que va en camino a recoger
  /// (POST /confirm-arrival → conductor_en_camino).
  final VoidCallback? onIniciarViaje;
  final VoidCallback? onCancelarViaje;

  /// Coordenadas para el mapa; las que falten no se marcan. El destino sólo
  /// se usa en la lista de datos, no en el mapa (la fase es la recogida).
  final LatLng? origenPos;
  final LatLng? destinoPos;
  final LatLng? vehiculoPos;

  /// Ruta conductor → recogida (GET /trips/:id/route, fase 'recogida').
  final List<LatLng>? ruta;
  final bool rutaAproximada;

  /// Texto del botón principal.
  final String textoAccion;

  const ViajeAceptadoScreen({
    super.key,
    this.nombreCliente = 'Cliente',
    this.ratingCliente = 5.0,
    this.avatarUrl,
    this.origen = 'Origen',
    this.destino = 'Destino',
    this.precioAcordado = '—',
    this.isStarting = false,
    this.isCancelling = false,
    this.onLlamar,
    this.onMensaje,
    this.onIniciarViaje,
    this.onCancelarViaje,
    this.origenPos,
    this.destinoPos,
    this.vehiculoPos,
    this.ruta,
    this.rutaAproximada = false,
    this.textoAccion = 'Voy en camino a recoger',
  });

  static const Color _textPrimary = ColoresApp.textoOscuro;
  static const Color _textSecondary = ColoresApp.textoSecundario;
  static const Color _divider = ColoresApp.borde;
  static const Color _star = ColoresApp.ambar;
  static const Color _greenDark = Color(0xFF15803D);
  static const Color _iconDisabled = Color(0xFFD1D5DB);

  bool get _busy => isStarting || isCancelling;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColoresApp.fondo,
      appBar: _buildAppBar(context),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const EncabezadoEstado(
              titulo: '¡Oferta aceptada!',
              detalle: 'Ve al punto de recogida. Avísale al cliente cuando salgas.',
              icono: Icons.local_shipping_rounded,
            ),
            const SizedBox(height: 14),
            _buildMapSection(),
            const SizedBox(height: 14),
            TarjetaBlanca(child: _buildClienteRow()),
            const SizedBox(height: 12),
            TarjetaBlanca(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildParada(Icons.trip_origin, ColoresApp.verde, 'Recogida', origen, destacada: true),
                  const SizedBox(height: 12),
                  _buildParada(Icons.location_on, Colors.red, 'Destino', destino),
                  const Divider(height: 26, color: _divider),
                  _buildPrecioRow(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomButtons(),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: ColoresApp.fondo,
      elevation: 0,
      centerTitle: true,
      title: const Text(
        'Viaje aceptado',
        style: TextStyle(color: _textPrimary, fontSize: 17, fontWeight: FontWeight.w700),
      ),
      leading: IconButton(
        icon: const Icon(Icons.chevron_left_rounded, color: _textPrimary, size: 28),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
    );
  }

  Widget _buildMapSection() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 200,
        child: MapaViaje(
          key: const Key('mapa_recogida'),
          origen: origenPos,
          vehiculo: vehiculoPos,
          ruta: ruta,
          rutaAproximada: rutaAproximada,
        ),
      ),
    );
  }

  Widget _buildClienteRow() {
    return Row(
      children: [
        MediaAvatar(
          path: avatarUrl,
          name: nombreCliente,
          radius: 26,
          backgroundColor: const Color(0xFFD1FAE5),
          foregroundColor: _greenDark,
          fontSize: 16,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(nombreCliente,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _textPrimary)),
              const SizedBox(height: 3),
              Row(
                children: [
                  const Icon(Icons.star_rounded, color: _star, size: 16),
                  const SizedBox(width: 3),
                  Text(ratingCliente.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textPrimary)),
                  const Text('  ·  Cliente', style: TextStyle(fontSize: 13, color: _textSecondary)),
                ],
              ),
            ],
          ),
        ),
        _buildActionIcon(Icons.phone_outlined, 'Llamar', onLlamar),
        const SizedBox(width: 10),
        _buildActionIcon(Icons.chat_bubble_outline_rounded, 'Chat', onMensaje),
      ],
    );
  }

  Widget _buildActionIcon(IconData icon, String tooltip, VoidCallback? onTap) {
    final disabled = onTap == null;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: CircleBorder(side: BorderSide(color: disabled ? _iconDisabled : _divider, width: 1.5)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, color: disabled ? _iconDisabled : _textPrimary, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildParada(IconData icono, Color color, String titulo, String texto, {bool destacada = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, size: 20, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: const TextStyle(fontSize: 12, color: _textSecondary)),
              const SizedBox(height: 2),
              Text(texto,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: destacada ? FontWeight.w700 : FontWeight.w500,
                    color: destacada ? _textPrimary : const Color(0xFF374151),
                  )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPrecioRow() {
    return Row(
      children: [
        const Expanded(
          child: Text('Precio acordado', style: TextStyle(fontSize: 14, color: _textSecondary)),
        ),
        Text(precioAcordado, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _textPrimary)),
      ],
    );
  }

  Widget _buildBottomButtons() {
    return BarraInferiorFija(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BotonPrincipal(
            key: const Key('btn_voy_en_camino'),
            texto: textoAccion,
            icono: Icons.navigation_rounded,
            cargando: isStarting,
            onPressed: (_busy || onIniciarViaje == null) ? null : onIniciarViaje,
          ),
          const SizedBox(height: 10),
          BotonSecundario(
            key: const Key('btn_cancelar_viaje_aceptado'),
            texto: 'Cancelar viaje',
            color: ColoresApp.rojo,
            cargando: isCancelling,
            onPressed: (_busy || onCancelarViaje == null) ? null : onCancelarViaje,
          ),
        ],
      ),
    );
  }
}
