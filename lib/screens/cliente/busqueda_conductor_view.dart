import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/trip.dart';
import 'cancel_trip_screen.dart' show componerMotivoCancelacion;
import 'nuevo_envio_screen.dart' show formatearMiles;

import 'rastreo_ui.dart';

const Color _kPrimary = RastreoColores.primario;
const Color _kTexto = RastreoColores.texto;
const Color _kGris = RastreoColores.gris;
const Color _kRojo = Color(0xFFE53935);
const Color _kVerde = RastreoColores.verde;

/// Vista "Buscando conductor" del cliente: el mapa ocupa toda la pantalla
/// (radio de búsqueda, pulso en el origen y vehículos cercanos), con una
/// barra superior flotante y una tarjeta inferior con el estado, las ofertas
/// recibidas, el resumen del viaje y el botón para cancelar.
///
/// No tiene lógica de negocio: [RastreoScreen] le pasa los datos y callbacks.
class BusquedaConductorView extends StatelessWidget {
  final Trip? trip;

  /// Mapa con el radio de búsqueda (en pruebas puede ser cualquier widget).
  final Widget mapa;
  final int vehiculosCercanos;
  final double radioKm;
  final int ofertas;
  final bool cancelando;

  /// Momento en que empezó la búsqueda (para el tiempo transcurrido).
  final DateTime inicioBusqueda;
  final VoidCallback onVerOfertas;
  final VoidCallback onCancelar;

  /// Título y acciones de la barra superior flotante.
  final String titulo;
  final List<Widget> acciones;

  const BusquedaConductorView({
    super.key,
    required this.trip,
    required this.mapa,
    required this.vehiculosCercanos,
    required this.ofertas,
    required this.cancelando,
    required this.inicioBusqueda,
    required this.onVerOfertas,
    required this.onCancelar,
    this.radioKm = 2,
    this.titulo = 'Buscando conductor',
    this.acciones = const [],
  });

  /// Fracción de la altura que la tarjeta inferior puede ocupar como máximo.
  static const double fraccionTarjeta = 0.62;

  @override
  Widget build(BuildContext context) {
    final maxPanel = MediaQuery.sizeOf(context).height * fraccionTarjeta;
    return ColoredBox(
      color: RastreoColores.fondo,
      child: Stack(
        children: [
          Positioned.fill(child: mapa),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: BarraRastreo(titulo: titulo, acciones: acciones),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
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
              child: SafeArea(
                top: false,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxPanel),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AsaHojaRastreo(),
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _Encabezado(
                                ofertas: ofertas,
                                inicio: inicioBusqueda,
                              ),
                              if (ofertas > 0) ...[
                                const SizedBox(height: 14),
                                _OfertasCard(
                                  cantidad: ofertas,
                                  onTap: onVerOfertas,
                                ),
                              ],
                              const SizedBox(height: 12),
                              _LineaCercanos(
                                cantidad: vehiculosCercanos,
                                radioKm: radioKm,
                              ),
                              const SizedBox(height: 14),
                              _ResumenViaje(trip: trip),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                        child: SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton.icon(
                            key: const Key('btn_cancelar_busqueda'),
                            onPressed: cancelando ? null : onCancelar,
                            icon: cancelando
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.close_rounded),
                            label: Text(
                              cancelando ? 'Cancelando…' : 'Cancelar búsqueda',
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _kRojo,
                              side: const BorderSide(color: Color(0xFFF3B4B2)),
                              textStyle: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Motivos para cancelar mientras se busca conductor.
const List<String> motivosCancelacionBusqueda = [
  'Cambié de opinión',
  'Error en la dirección',
  'Conseguí otro transporte',
  'Tarda mucho en aparecer un conductor',
  'Otro motivo',
];

/// Hoja para confirmar la cancelación de la búsqueda eligiendo un motivo
/// (y un comentario opcional). Devuelve el motivo a enviar al backend, o
/// null si el usuario sigue buscando.
Future<String?> elegirMotivoCancelacionBusqueda(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (_) => const _MotivoCancelacionSheet(),
  );
}

class _MotivoCancelacionSheet extends StatefulWidget {
  const _MotivoCancelacionSheet();

  @override
  State<_MotivoCancelacionSheet> createState() =>
      _MotivoCancelacionSheetState();
}

class _MotivoCancelacionSheetState extends State<_MotivoCancelacionSheet> {
  String? _motivo;
  final _comentario = TextEditingController();

  @override
  void dispose() {
    _comentario.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final teclado = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: teclado),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '¿Cancelar la búsqueda?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _kTexto,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Los conductores dejarán de ver tu solicitud y las ofertas recibidas se perderán. Cuéntanos por qué:',
                      style: TextStyle(
                        fontSize: 14,
                        color: _kGris,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    RadioGroup<String>(
                      groupValue: _motivo,
                      onChanged: (v) => setState(() => _motivo = v),
                      child: Column(
                        children: [
                          for (final m in motivosCancelacionBusqueda)
                            RadioListTile<String>(
                              value: m,
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              activeColor: _kRojo,
                              title: Text(
                                m,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: _kTexto,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    TextField(
                      key: const Key('campo_comentario_cancelacion'),
                      controller: _comentario,
                      maxLines: 2,
                      maxLength: 200,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Comentario (opcional)',
                        counterText: '',
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Botones siempre visibles aunque el contenido haga scroll.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Seguir buscando'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      key: const Key('btn_confirmar_cancelacion'),
                      onPressed: _motivo == null
                          ? null
                          : () => Navigator.pop(
                              context,
                              componerMotivoCancelacion(
                                _motivo!,
                                _comentario.text,
                              ),
                            ),
                      style: FilledButton.styleFrom(
                        backgroundColor: _kRojo,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Sí, cancelar'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Vehículos disponibles cerca del origen, o el aviso honesto de que aún
/// no hay ninguno.
class _LineaCercanos extends StatelessWidget {
  final int cantidad;
  final double radioKm;
  const _LineaCercanos({required this.cantidad, required this.radioKm});

  @override
  Widget build(BuildContext context) {
    final radio = radioKm == radioKm.roundToDouble()
        ? radioKm.toStringAsFixed(0)
        : radioKm.toString();
    final hay = cantidad > 0;
    final texto = hay
        ? '$cantidad ${cantidad == 1 ? 'vehículo disponible' : 'vehículos disponibles'} a menos de $radio km'
        : 'Aún no hay vehículos cerca, seguimos buscando';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: hay ? RastreoColores.primarioSuave : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.local_shipping_outlined,
            size: 18,
            color: hay ? _kPrimary : _kGris,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: hay ? _kTexto : _kGris,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Encabezado extends StatelessWidget {
  final int ofertas;
  final DateTime inicio;
  const _Encabezado({required this.ofertas, required this.inicio});

  @override
  Widget build(BuildContext context) {
    final hayOfertas = ofertas > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Icono fijo (el pulso animado ya está en el mapa).
            Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                color: RastreoColores.primarioSuave,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.radar_rounded, size: 18, color: _kPrimary),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Buscando conductor…',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: _kTexto,
                  height: 1.25,
                ),
              ),
            ),
            const SizedBox(width: 12),
            _TiempoBuscando(inicio: inicio),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          hayOfertas
              ? 'Revisa las ofertas y acepta la que prefieras. Seguimos recibiendo más.'
              : 'Enviamos tu solicitud a los conductores cercanos. Te avisaremos apenas alguno te haga una oferta.',
          style: const TextStyle(fontSize: 14, color: _kGris, height: 1.35),
        ),
      ],
    );
  }
}

/// Tiempo de búsqueda (mm:ss). Se redibuja solo a sí mismo cada segundo.
class _TiempoBuscando extends StatefulWidget {
  final DateTime inicio;
  const _TiempoBuscando({required this.inicio});

  @override
  State<_TiempoBuscando> createState() => _TiempoBuscandoState();
}

class _TiempoBuscandoState extends State<_TiempoBuscando> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var d = DateTime.now().difference(widget.inicio);
    if (d.isNegative) d = Duration.zero;
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final texto = h > 0 ? '$h:$m:$s' : '$m:$s';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: RastreoColores.primarioSuave,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.schedule, size: 14, color: _kPrimary),
          const SizedBox(width: 4),
          Text(
            texto,
            semanticsLabel: 'Buscando hace $texto',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _kPrimary,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _OfertasCard extends StatelessWidget {
  final int cantidad;
  final VoidCallback onTap;
  const _OfertasCard({required this.cantidad, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFECFDF3),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: const Key('card_ofertas'),
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFA7E3BD)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: _kVerde,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '$cantidad',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  cantidad == 1
                      ? '1 oferta recibida'
                      : '$cantidad ofertas recibidas',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF14532D),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _kVerde,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Ver ofertas',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResumenViaje extends StatelessWidget {
  final Trip? trip;
  const _ResumenViaje({required this.trip});

  @override
  Widget build(BuildContext context) {
    final t = trip;
    final carga = [t?.descripcion, t?.carga]
        .whereType<String>()
        .map((s) => s.trim())
        .firstWhere((s) => s.isNotEmpty, orElse: () => '');
    final precio = t?.precioEstimado;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: RastreoColores.borde),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TituloSeccionRastreo('Tu solicitud'),
          const SizedBox(height: 10),
          LineaDatoRastreo(
            icon: Icons.trip_origin,
            color: _kVerde,
            label: 'Origen',
            valor: t?.origen?.direccion,
            maxLines: 1,
          ),
          const SizedBox(height: 10),
          LineaDatoRastreo(
            icon: Icons.location_on,
            color: RastreoColores.rojo,
            label: 'Destino',
            valor: t?.destino?.direccion,
            maxLines: 1,
          ),
          if (carga.isNotEmpty) ...[
            const SizedBox(height: 10),
            LineaDatoRastreo(
              icon: Icons.inventory_2_outlined,
              color: _kGris,
              label: 'Carga',
              valor: carga,
            ),
          ],
          if (precio != null) ...[
            const Divider(height: 22, color: RastreoColores.borde),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Precio ofrecido',
                    style: TextStyle(fontSize: 14, color: _kGris),
                  ),
                ),
                Text(
                  '\$${formatearMiles(precio.round().toString())} COP',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _kTexto,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Anillos que se expanden alrededor del punto de recogida en el mapa.
class PulsoBusqueda extends StatefulWidget {
  final double size;
  const PulsoBusqueda({super.key, this.size = 140});

  @override
  State<PulsoBusqueda> createState() => _PulsoBusquedaState();
}

class _PulsoBusquedaState extends State<PulsoBusqueda>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => SizedBox(
            width: widget.size,
            height: widget.size,
            child: Stack(
              alignment: Alignment.center,
              children: List.generate(2, (i) {
                final phase = (_ctrl.value + i / 2) % 1.0;
                return Container(
                  width: widget.size * (0.2 + 0.8 * phase),
                  height: widget.size * (0.2 + 0.8 * phase),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _kPrimary.withValues(alpha: 0.28 * (1 - phase)),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
