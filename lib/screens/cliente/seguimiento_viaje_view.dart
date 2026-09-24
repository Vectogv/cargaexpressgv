import 'package:flutter/material.dart';

import '../../models/trip.dart';
import 'nuevo_envio_screen.dart' show formatearMiles;
import 'rastreo_ui.dart';

/// Vista "viaje en curso" del cliente (conductor asignado, en camino, en el
/// origen, viaje en curso, SOS): el mapa con la ruta ocupa toda la pantalla,
/// con la barra superior flotante y una hoja inferior arrastrable por
/// secciones: estado + ETA, conductor, detalles del viaje y acciones.
///
/// No tiene lógica de negocio: [RastreoScreen] le pasa los datos y callbacks.
class SeguimientoViajeView extends StatelessWidget {
  /// Título de la barra superior (estado del viaje).
  final String titulo;

  /// Mapa del viaje (en pruebas puede ser cualquier widget).
  final Widget mapa;

  /// Muestra "Recentrar" cuando el usuario movió el mapa.
  final VoidCallback? onRecentrar;

  /// Frase del estado en la hoja y su detalle.
  final String estado;
  final String? estadoDetalle;
  final Color colorEstado;

  /// ETA en vivo ("8 min") o null si no hay datos reales.
  final String? eta;
  final String etaEtiqueta;

  /// Distancia en vivo del conductor ("350 m", "--").
  final String distancia;
  final String distanciaEtiqueta;

  final Trip? trip;
  final String calificacion;

  /// Distancia total del viaje ya formateada, o null si no se conoce.
  final String? distanciaViaje;

  /// null oculta el botón (el chat sólo existe en ciertos estados).
  final VoidCallback? onChat;
  final VoidCallback onLlamar;
  final VoidCallback onReportar;
  final VoidCallback? onSos;
  final bool sosEnviando;
  final VoidCallback? onCancelar;
  final String textoCancelar;

  const SeguimientoViajeView({
    super.key,
    required this.titulo,
    required this.mapa,
    required this.estado,
    required this.distancia,
    required this.distanciaEtiqueta,
    required this.trip,
    required this.calificacion,
    required this.onLlamar,
    required this.onReportar,
    required this.onSos,
    required this.onCancelar,
    required this.textoCancelar,
    this.onRecentrar,
    this.estadoDetalle,
    this.colorEstado = RastreoColores.primario,
    this.eta,
    this.etaEtiqueta = 'Llegada estimada',
    this.distanciaViaje,
    this.onChat,
    this.sosEnviando = false,
  });

  /// Alto inicial de la hoja (fracción de la pantalla). El mapa encuadra la
  /// ruta por encima de ella.
  static const double tamanoInicialHoja = 0.44;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    return ColoredBox(
      color: RastreoColores.fondo,
      child: Stack(
        children: [
          Positioned.fill(child: mapa),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: BarraRastreo(
              titulo: titulo,
              acciones: [_BotonSos(onPressed: onSos, enviando: sosEnviando)],
            ),
          ),
          if (onRecentrar != null)
            Positioned(
              top: padding.top + 8 + 48 + 12,
              right: 12,
              child: Material(
                color: Colors.white,
                elevation: 3,
                shadowColor: const Color(0x33000000),
                shape: const StadiumBorder(),
                child: InkWell(
                  key: const Key('btn_recentrar'),
                  customBorder: const StadiumBorder(),
                  onTap: onRecentrar,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.my_location_rounded,
                          size: 18,
                          color: RastreoColores.primario,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Recentrar',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: RastreoColores.primario,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          DraggableScrollableSheet(
            key: const Key('hoja_seguimiento'),
            initialChildSize: tamanoInicialHoja,
            minChildSize: 0.22,
            maxChildSize: 0.9,
            builder: (context, controller) => DecoratedBox(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x1F000000),
                    blurRadius: 20,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              // Contenido corto: se construye entero (no perezoso) para que
              // todas las acciones existan aunque estén fuera de la vista.
              child: SingleChildScrollView(
                controller: controller,
                padding: EdgeInsets.fromLTRB(20, 0, 20, padding.bottom + 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AsaHojaRastreo(),
                    const SizedBox(height: 6),
                    _SeccionEstado(
                      estado: estado,
                      detalle: estadoDetalle,
                      color: colorEstado,
                      eta: eta,
                      etaEtiqueta: etaEtiqueta,
                      distancia: distancia,
                      distanciaEtiqueta: distanciaEtiqueta,
                    ),
                    const SizedBox(height: 16),
                    _SeccionConductor(
                      trip: trip,
                      calificacion: calificacion,
                      onChat: onChat,
                      onLlamar: onLlamar,
                    ),
                    const SizedBox(height: 20),
                    _SeccionDetalles(
                      trip: trip,
                      distanciaViaje: distanciaViaje,
                    ),
                    const SizedBox(height: 20),
                    _SeccionAcciones(
                      onReportar: onReportar,
                      onCancelar: onCancelar,
                      textoCancelar: textoCancelar,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BotonSos extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool enviando;
  const _BotonSos({required this.onPressed, required this.enviando});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: RastreoColores.rojo,
      shape: const StadiumBorder(),
      elevation: 3,
      shadowColor: const Color(0x33000000),
      child: InkWell(
        key: const Key('btn_sos'),
        customBorder: const StadiumBorder(),
        onTap: enviando ? null : onPressed,
        child: SizedBox(
          height: 48,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (enviando)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                else
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                const SizedBox(width: 6),
                const Text(
                  'SOS',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SeccionEstado extends StatelessWidget {
  final String estado;
  final String? detalle;
  final Color color;
  final String? eta;
  final String etaEtiqueta;
  final String distancia;
  final String distanciaEtiqueta;

  const _SeccionEstado({
    required this.estado,
    required this.detalle,
    required this.color,
    required this.eta,
    required this.etaEtiqueta,
    required this.distancia,
    required this.distanciaEtiqueta,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                estado,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: RastreoColores.texto,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
        if (detalle != null) ...[
          const SizedBox(height: 4),
          Text(
            detalle!,
            style: const TextStyle(
              fontSize: 14,
              color: RastreoColores.gris,
              height: 1.35,
            ),
          ),
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            if (eta != null) ...[
              Expanded(
                child: _Metrica(
                  icon: Icons.access_time,
                  valor: eta!,
                  etiqueta: etaEtiqueta,
                  destacada: true,
                  valorKey: const Key('eta_rastreo'),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: _Metrica(
                icon: Icons.place_outlined,
                valor: distancia,
                etiqueta: distanciaEtiqueta,
                destacada: eta == null,
                valorKey: const Key('distancia_rastreo'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Metrica extends StatelessWidget {
  final IconData icon;
  final String valor;
  final String etiqueta;
  final bool destacada;
  final Key valorKey;
  const _Metrica({
    required this.icon,
    required this.valor,
    required this.etiqueta,
    required this.destacada,
    required this.valorKey,
  });

  @override
  Widget build(BuildContext context) {
    final color = destacada ? RastreoColores.primario : RastreoColores.texto;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: destacada
            ? RastreoColores.primarioSuave
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  valor,
                  key: valorKey,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: color,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            etiqueta,
            maxLines: 2,
            style: const TextStyle(fontSize: 12, color: RastreoColores.gris),
          ),
        ],
      ),
    );
  }
}

class _SeccionConductor extends StatelessWidget {
  final Trip? trip;
  final String calificacion;
  final VoidCallback? onChat;
  final VoidCallback onLlamar;

  const _SeccionConductor({
    required this.trip,
    required this.calificacion,
    required this.onChat,
    required this.onLlamar,
  });

  static String _iniciales(String nombre) {
    final partes = nombre
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (partes.isEmpty) return '';
    final a = partes.first[0];
    final b = partes.length > 1 ? partes[1][0] : '';
    return (a + b).toUpperCase();
  }

  static String? _vehiculo(String? tipo) {
    final t = (tipo ?? '').trim().replaceAll('_', ' ');
    if (t.isEmpty) return null;
    return t[0].toUpperCase() + t.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final conductor = trip?.conductor;
    final nombre = (conductor?.nombre ?? '').trim().isEmpty
        ? 'Conductor'
        : conductor!.nombre!.trim();
    final iniciales = _iniciales(conductor?.nombre ?? '');
    final vehiculo = _vehiculo(conductor?.tipoVehiculo);
    final placa = (conductor?.placa ?? '').trim();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RastreoColores.borde),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: RastreoColores.primarioSuave,
                child: iniciales.isEmpty
                    ? const Icon(
                        Icons.person,
                        color: RastreoColores.primario,
                        size: 28,
                      )
                    : Text(
                        iniciales,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: RastreoColores.primario,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: RastreoColores.texto,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (conductor != null) ...[
                          const Icon(
                            Icons.star_rounded,
                            color: Color(0xFFF59E0B),
                            size: 18,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            calificacion,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: RastreoColores.texto,
                            ),
                          ),
                        ],
                        if (vehiculo != null) ...[
                          if (conductor != null)
                            const Text(
                              '  ·  ',
                              style: TextStyle(
                                color: RastreoColores.gris,
                                fontSize: 13,
                              ),
                            ),
                          Flexible(
                            child: Text(
                              vehiculo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                color: RastreoColores.gris,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (placa.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7D6),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE5C94A)),
                  ),
                  child: Text(
                    placa.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      color: RastreoColores.texto,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (onChat != null) ...[
                Expanded(
                  child: FilledButton.icon(
                    key: const Key('btn_chat_conductor'),
                    onPressed: onChat,
                    icon: const Icon(Icons.chat_bubble_outline, size: 18),
                    label: const Text('Chat'),
                    style: FilledButton.styleFrom(
                      backgroundColor: RastreoColores.primario,
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('btn_llamar_conductor'),
                  onPressed: onLlamar,
                  icon: const Icon(Icons.phone_outlined, size: 18),
                  label: const Text('Llamar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: RastreoColores.primario,
                    side: const BorderSide(color: Color(0xFFBFD3FB)),
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SeccionDetalles extends StatelessWidget {
  final Trip? trip;
  final String? distanciaViaje;
  const _SeccionDetalles({required this.trip, required this.distanciaViaje});

  @override
  Widget build(BuildContext context) {
    final t = trip;
    final carga = [t?.descripcion, t?.carga]
        .whereType<String>()
        .map((s) => s.trim())
        .firstWhere((s) => s.isNotEmpty, orElse: () => '');
    // Precio final si el backend ya lo fijó; si no, el estimado del viaje.
    final precio = t?.precioFinal ?? t?.precioEstimado;
    final etiquetaPrecio = t?.precioFinal != null
        ? 'Precio acordado'
        : 'Precio estimado';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TituloSeccionRastreo('Detalles del viaje'),
        const SizedBox(height: 12),
        LineaDatoRastreo(
          icon: Icons.trip_origin,
          color: RastreoColores.verde,
          label: 'Origen',
          valor: t?.origen?.direccion,
          maxLines: 3,
        ),
        const SizedBox(height: 12),
        LineaDatoRastreo(
          icon: Icons.location_on,
          color: RastreoColores.rojo,
          label: 'Destino',
          valor: t?.destino?.direccion,
          maxLines: 3,
        ),
        if (carga.isNotEmpty) ...[
          const SizedBox(height: 12),
          LineaDatoRastreo(
            icon: Icons.inventory_2_outlined,
            color: RastreoColores.gris,
            label: 'Carga',
            valor: carga,
            maxLines: 3,
          ),
        ],
        if (precio != null || distanciaViaje != null) ...[
          const Divider(height: 26, color: RastreoColores.borde),
          if (precio != null)
            _FilaValor(
              etiqueta: etiquetaPrecio,
              valor: '\$${formatearMiles(precio.round().toString())} COP',
            ),
          if (precio != null && distanciaViaje != null)
            const SizedBox(height: 8),
          if (distanciaViaje != null)
            _FilaValor(etiqueta: 'Distancia', valor: distanciaViaje!),
        ],
      ],
    );
  }
}

class _FilaValor extends StatelessWidget {
  final String etiqueta;
  final String valor;
  const _FilaValor({required this.etiqueta, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            etiqueta,
            style: const TextStyle(fontSize: 14, color: RastreoColores.gris),
          ),
        ),
        Text(
          valor,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: RastreoColores.texto,
          ),
        ),
      ],
    );
  }
}

class _SeccionAcciones extends StatelessWidget {
  final VoidCallback onReportar;
  final VoidCallback? onCancelar;
  final String textoCancelar;
  const _SeccionAcciones({
    required this.onReportar,
    required this.onCancelar,
    required this.textoCancelar,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TituloSeccionRastreo('¿Algo no va bien?'),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          key: const Key('btn_reportar_problema'),
          onPressed: onReportar,
          icon: const Icon(Icons.report_gmailerrorred_outlined, size: 20),
          label: const Text('Reportar un problema'),
          style: OutlinedButton.styleFrom(
            foregroundColor: RastreoColores.texto,
            side: const BorderSide(color: RastreoColores.borde),
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          key: const Key('btn_cancelar_viaje'),
          onPressed: onCancelar,
          icon: const Icon(Icons.cancel_outlined, size: 20),
          label: Text(textoCancelar),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFFE53935),
            minimumSize: const Size.fromHeight(48),
          ),
        ),
      ],
    );
  }
}
