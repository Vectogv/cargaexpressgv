import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/trip.dart';
import '../../services/server_clock.dart';
import 'cancel_trip_screen.dart' show componerMotivoCancelacion;

import 'rastreo_ui.dart';
import '../../core/formato_dinero.dart';
import '../../core/formato_hora.dart';

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

  /// Escalera de acompañamiento (`trip.busqueda`): mensaje por etapa, precio
  /// sugerido y, en el cierre, qué hacer. Una acción en curso deshabilita las
  /// demás ([accionando]).
  final bool accionando;
  final ValueChanged<int>? onSubirPrecio;
  final VoidCallback? onSeguirEsperando;
  final VoidCallback? onProgramar;

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
    this.accionando = false,
    this.onSubirPrecio,
    this.onSeguirEsperando,
    this.onProgramar,
  });

  Map<String, dynamic>? get _busqueda => trip?.busqueda;
  String? get _etapa => _busqueda?['etapa'] as String?;

  /// `{min, max}` del servidor; null si no sugirió nada.
  ({int min, int max})? get _precioSugerido {
    final p = _busqueda?['precioSugerido'];
    if (p is! Map) return null;
    final min = (p['min'] as num?)?.toInt();
    final max = (p['max'] as num?)?.toInt();
    if (min == null || max == null) return null;
    return (min: min, max: max);
  }

  /// El servidor sigue en `sugerencia` después de subir el precio: la tarjeta
  /// solo tiene sentido mientras el precio esté por debajo del mínimo.
  bool get _mostrarSugerencia =>
      _etapa == 'sugerencia' &&
      _precioSugerido != null &&
      (trip?.precioEstimado ?? 0) < _precioSugerido!.min;

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
                                mensaje: _busqueda?['mensaje'] as String?,
                              ),
                              if (_mostrarSugerencia) ...[
                                const SizedBox(height: 14),
                                _SugerenciaCard(
                                  rango: _precioSugerido!,
                                  ocupado: accionando,
                                  onSubir: onSubirPrecio,
                                ),
                              ],
                              if (_etapa == 'cierre') ...[
                                const SizedBox(height: 14),
                                _CierreCard(
                                  hasta: _busqueda?['cierreHasta'] as String?,
                                  ocupado: accionando || cancelando,
                                  onSeguir: onSeguirEsperando,
                                  onProgramar: onProgramar,
                                ),
                              ],
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

  /// Mensaje de la etapa actual (`busqueda.mensaje`); sin él, el texto fijo.
  final String? mensaje;
  const _Encabezado({required this.ofertas, required this.inicio, this.mensaje});

  @override
  Widget build(BuildContext context) {
    final hayOfertas = ofertas > 0;
    final texto = hayOfertas
        ? 'Revisa las ofertas y acepta la que prefieras. Seguimos recibiendo más.'
        : (mensaje?.trim().isNotEmpty == true
            ? mensaje!.trim()
            : 'Enviamos tu solicitud a los conductores cercanos. Te avisaremos apenas alguno te haga una oferta.');
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
          texto,
          key: const Key('texto_etapa_busqueda'),
          style: const TextStyle(fontSize: 14, color: _kGris, height: 1.35),
        ),
      ],
    );
  }
}

/// Etapa `sugerencia`: rango de precio de viajes parecidos con [Subir a $X]
/// (el mínimo del rango) y [Mantener mi precio], que solo oculta la tarjeta
/// en esta pantalla (al reabrirla vuelve a salir: el servidor sigue sugiriendo).
class _SugerenciaCard extends StatefulWidget {
  final ({int min, int max}) rango;
  final bool ocupado;
  final ValueChanged<int>? onSubir;
  const _SugerenciaCard({required this.rango, required this.ocupado, required this.onSubir});

  @override
  State<_SugerenciaCard> createState() => _SugerenciaCardState();
}

class _SugerenciaCardState extends State<_SugerenciaCard> {
  bool _oculta = false;

  @override
  Widget build(BuildContext context) {
    if (_oculta) return const SizedBox.shrink();
    final r = widget.rango;
    return _TarjetaEscalera(
      color: const Color(0xFFFFFBEB),
      borde: const Color(0xFFFDE68A),
      icono: Icons.lightbulb_outline_rounded,
      colorIcono: const Color(0xFFD97706),
      titulo: 'Los viajes parecidos se pagan entre ${formatearPesos(r.min)} y ${formatearPesos(r.max)}',
      detalle: 'Subir tu precio ayuda a que un conductor acepte más rápido.',
      acciones: [
        _BotonEscalera(
          key: const Key('btn_subir_precio'),
          texto: 'Subir a ${formatearPesos(r.min)}',
          relleno: true,
          onPressed: widget.ocupado || widget.onSubir == null ? null : () => widget.onSubir!(r.min),
        ),
        _BotonEscalera(
          key: const Key('btn_mantener_precio'),
          texto: 'Mantener mi precio',
          onPressed: widget.ocupado ? null : () => setState(() => _oculta = true),
        ),
      ],
    );
  }
}

/// Etapa `cierre`: nadie ofertó; el cliente decide antes de que se cancele.
class _CierreCard extends StatelessWidget {
  final String? hasta;
  final bool ocupado;
  final VoidCallback? onSeguir;
  final VoidCallback? onProgramar;
  const _CierreCard({
    required this.hasta,
    required this.ocupado,
    required this.onSeguir,
    required this.onProgramar,
  });

  @override
  Widget build(BuildContext context) {
    final limite = DateTime.tryParse(hasta ?? '')?.toLocal();
    final hora = limite == null
        ? null
        : hora12(limite);
    return _TarjetaEscalera(
      color: const Color(0xFFFFF1F2),
      borde: const Color(0xFFFECDD3),
      icono: Icons.hourglass_bottom_rounded,
      colorIcono: _kRojo,
      titulo: '¿Qué quieres hacer?',
      detalle: hora == null
          ? 'Si no eliges, la búsqueda se cancela sola sin costo.'
          : 'Si no eliges antes de las $hora, la búsqueda se cancela sola sin costo.',
      acciones: [
        _BotonEscalera(
          key: const Key('btn_seguir_esperando'),
          texto: 'Seguir esperando',
          relleno: true,
          onPressed: ocupado || onSeguir == null ? null : onSeguir,
        ),
        _BotonEscalera(
          key: const Key('btn_programar_mas_tarde'),
          texto: 'Programar para más tarde',
          onPressed: ocupado || onProgramar == null ? null : onProgramar,
        ),
      ],
    );
  }
}

class _TarjetaEscalera extends StatelessWidget {
  final Color color;
  final Color borde;
  final IconData icono;
  final Color colorIcono;
  final String titulo;
  final String detalle;
  final List<Widget> acciones;
  const _TarjetaEscalera({
    required this.color,
    required this.borde,
    required this.icono,
    required this.colorIcono,
    required this.titulo,
    required this.detalle,
    required this.acciones,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icono, size: 20, color: colorIcono),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  titulo,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _kTexto, height: 1.3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(detalle, style: const TextStyle(fontSize: 13, color: _kGris, height: 1.35)),
          const SizedBox(height: 10),
          for (var i = 0; i < acciones.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            acciones[i],
          ],
        ],
      ),
    );
  }
}

class _BotonEscalera extends StatelessWidget {
  final String texto;
  final bool relleno;
  final VoidCallback? onPressed;
  const _BotonEscalera({
    super.key,
    required this.texto,
    required this.onPressed,
    this.relleno = false,
  });

  @override
  Widget build(BuildContext context) {
    final forma = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    const estiloTexto = TextStyle(fontSize: 14, fontWeight: FontWeight.w600);
    final hijo = Text(texto, maxLines: 1, overflow: TextOverflow.ellipsis);
    return SizedBox(
      height: 44,
      child: relleno
          ? FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(backgroundColor: _kPrimary, shape: forma, textStyle: estiloTexto),
              child: hijo,
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: _kPrimary,
                backgroundColor: Colors.white,
                side: BorderSide(color: _kPrimary.withValues(alpha: 0.45)),
                shape: forma,
                textStyle: estiloTexto,
              ),
              child: hijo,
            ),
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
    // `inicio` suele ser el createdAt del backend: se compara con su reloj.
    var d = ServerClock.ahora().difference(widget.inicio);
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
    final reservaTexto = formatoFechaHoraReserva(t?.fechaProgramada, t?.horaProgramada);
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
            icon: reservaTexto != null ? Icons.event_available : Icons.bolt,
            color: RastreoColores.primario,
            label: 'Modo',
            valor: reservaTexto != null ? 'Reserva: $reservaTexto' : 'Servicio para ya',
          ),
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
                  '${formatearPesos(precio)} COP',
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
