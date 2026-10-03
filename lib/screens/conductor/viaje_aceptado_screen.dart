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

  /// Tipo de vehículo del conductor (furgón/camioneta/carro/moto), para
  /// dibujarlo en el mapa con su ícono real en vez de uno genérico.
  final String? tipoVehiculo;

  /// Ruta conductor → recogida (GET /trips/:id/route, fase 'recogida').
  final List<LatLng>? ruta;

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
    this.tipoVehiculo,
    this.ruta,
    this.textoAccion = 'Voy en camino a recoger',
  });

  static const Color _greenDark = ColoresApp.verdeOscuro;

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
                  const Divider(height: 26, color: ColoresApp.borde),
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
        style: TextStyle(color: ColoresApp.textoOscuro, fontSize: 17, fontWeight: FontWeight.w700),
      ),
      leading: IconButton(
        icon: const Icon(Icons.chevron_left_rounded, color: ColoresApp.textoOscuro, size: 28),
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
          dibujarVehiculo: true,
          tipoVehiculo: tipoVehiculo,
          etiquetaVehiculo: 'Tú',
          ruta: ruta,
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
          backgroundColor: ColoresApp.verdeFondo,
          foregroundColor: _greenDark,
          fontSize: 15,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(nombreCliente,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: ColoresApp.textoOscuro)),
              const SizedBox(height: 3),
              Row(
                children: [
                  const Icon(Icons.star_rounded, color: ColoresApp.ambar, size: 16),
                  const SizedBox(width: 3),
                  Text(ratingCliente.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ColoresApp.textoOscuro)),
                  const Text('  ·  Cliente', style: TextStyle(fontSize: 13, color: ColoresApp.textoSecundario)),
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
        shape: CircleBorder(side: BorderSide(color: disabled ? ColoresApp.bordeCampo : ColoresApp.borde, width: 1.5)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, color: disabled ? ColoresApp.bordeCampo : ColoresApp.textoOscuro, size: 20),
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
              Text(titulo, style: const TextStyle(fontSize: 12, color: ColoresApp.textoSecundario)),
              const SizedBox(height: 2),
              Text(texto,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: destacada ? FontWeight.w700 : FontWeight.w500,
                    color: destacada ? ColoresApp.textoOscuro : ColoresApp.gris,
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
          child: Text('Precio acordado', style: TextStyle(fontSize: 13, color: ColoresApp.textoSecundario)),
        ),
        Text(precioAcordado, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: ColoresApp.textoOscuro)),
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
