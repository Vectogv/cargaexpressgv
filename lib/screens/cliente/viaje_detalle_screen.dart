import 'dart:async';

import 'package:flutter/material.dart';
import '../../contracts/calificacion.dart' show etiquetaCalificacionConductor;
import '../../contracts/cancelacion.dart';
import '../../contracts/trip_status.dart';
import '../../services/api_client.dart';
import '../../services/api/http_client.dart' show ApiException;
import '../../services/api/offer_service.dart';
import '../../services/api/trip_service.dart';
import '../../services/report_service.dart';
import '../../services/socket_service_client.dart';
import '../../widgets/error_carga.dart';
import '../conductor/reportar_cliente_screen.dart';
import '../shared/ui_compartida.dart' show BotonPrincipal, BotonSecundario, ColoresApp, DialogoApp, cifrasTabulares;
import 'cancel_trip_screen.dart';
import 'chat_screen.dart';
import 'ofertas_recibidas_screen.dart' show intervaloSondeoOfertas;
import 'rastreo_screen.dart';
import '../../core/formato_dinero.dart';
import '../../core/formato_hora.dart';

class ViajeDetalleScreen extends StatefulWidget {
  final dynamic tripId;

  /// Vista del conductor (desde su historial): tarjeta del cliente, ganancias
  /// del viaje y "Reportar cliente"; sin calificar (eso es del cliente).
  final bool comoConductor;
  const ViajeDetalleScreen({super.key, required this.tripId, this.comoConductor = false});

  /// Minutos que el conductor tiene para reportar después de cerrar el viaje.
  static const minutosParaReportar = 30;

  @override
  State<ViajeDetalleScreen> createState() => _ViajeDetalleScreenState();
}

class _ViajeDetalleScreenState extends State<ViajeDetalleScreen> {
  Map<String, dynamic>? _trip;
  bool _loading = true;
  bool _rated = false;
  int _rating = 0;
  /// El conductor ya reportó este viaje. Se recuerda en el teléfono
  /// ([ReportService.yaReportado]) porque el detalle del backend no lo informa.
  bool _reportado = false;

  // Reserva (`reservado`): sin conductor, se sondean las ofertas cada 5 s
  // (respaldo del socket `new:offer`); con conductor, se relee el viaje cada
  // 20 s para abrir el rastreo cuando el servidor la active (`aceptado`).
  List<Map<String, dynamic>> _ofertas = [];
  String? _aceptandoId;
  Timer? _sondeo;
  int _tick = 0;
  final _subs = <StreamSubscription<Map<String, dynamic>>>[];

  @override
  void initState() {
    super.initState();
    _load();
    if (!widget.comoConductor) {
      final s = SocketServiceClient.instance;
      _subs.addAll([
        s.onNewOffer.listen((_) => _trasFrame(_cargarOfertas)),
        s.onTripOfferReceived.listen((_) => _trasFrame(_cargarOfertas)),
        s.onTripStatus.listen((d) {
          if ((d['id'] ?? d['tripId'] ?? d['viajeId'])?.toString() == widget.tripId.toString()) _trasFrame(_refrescarReserva);
        }),
      ]);
    }
  }

  @override
  void dispose() {
    _sondeo?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  /// En segundo plano Flutter no pinta hasta el próximo toque: se fuerza.
  void _trasFrame(VoidCallback fn) {
    WidgetsBinding.instance.addPostFrameCallback((_) => fn());
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  bool get _esReserva => !widget.comoConductor && _trip?['estado'] == TripStatus.reservado;
  bool get _reservaSinConductor => _esReserva && _trip?['conductor'] == null;

  void _ajustarSondeo() {
    if (!_esReserva) {
      _sondeo?.cancel();
      _sondeo = null;
      return;
    }
    _sondeo ??= Timer.periodic(intervaloSondeoOfertas, (_) {
      _tick++;
      if (_reservaSinConductor) _cargarOfertas();
      if (_tick % 4 == 0) _refrescarReserva();
    });
    if (_reservaSinConductor) _cargarOfertas();
  }

  Future<void> _cargarOfertas() async {
    if (!_reservaSinConductor) return;
    try {
      final lista = await OfferService.getOffers(widget.tripId);
      if (mounted) setState(() => _ofertas = lista);
    } catch (_) {
      // Sin red: se reintenta en el próximo sondeo.
    }
  }

  /// Relee la reserva sin spinner. Si el servidor ya la activó (`aceptado`),
  /// abre el rastreo normal; si se canceló, el detalle lo muestra.
  Future<void> _refrescarReserva() async {
    if (!_esReserva) return;
    try {
      final data = await ApiClient.instance.getTripDetail(widget.tripId);
      if (!mounted) return;
      setState(() => _trip = data);
      _ajustarSondeo();
      if (_estaActivo(data['estado']?.toString())) {
        _abrirRastreo();
      } else {
        _revisarPlazo();
      }
    } catch (_) {}
  }

  /// El conductor asignado pidió más tiempo (`plazo.estado == 'pendiente'`):
  /// el cliente acepta (se corre la hora) o rechaza (la reserva se libera y
  /// vuelve a recibir ofertas). La reserva no sale en /trips/active, así que
  /// el aviso vive aquí; el push `reserva_plazo` abre esta pantalla.
  bool _dialogoPlazoAbierto = false;

  Future<void> _revisarPlazo() async {
    final plazo = _trip?['plazo'];
    if (!_esReserva || plazo is! Map || plazo['estado'] != 'pendiente' || _dialogoPlazoAbierto) return;
    // `expiraEn` (ISO): pasado ese momento el servidor ya lo da por expirado
    // (409 SIN_PLAZO_PENDIENTE), así que no vale la pena preguntar.
    final expira = DateTime.tryParse(plazo['expiraEn']?.toString() ?? '')?.toLocal();
    if (expira != null && expira.isBefore(DateTime.now())) return;
    final antesDe = expira == null
        ? ''
        : ' Responde antes de las ${hora12(expira)}.';
    _dialogoPlazoAbierto = true;
    final aceptar = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DialogoApp(
        icono: Icons.schedule_rounded,
        titulo: 'El conductor pide ${plazo['minutos']} min más',
        cuerpo: 'No podrá llegar a la hora programada. ¿Le das más tiempo? Si rechazas, tu reserva vuelve a recibir ofertas.$antesDe',
        textoPrincipal: 'Aceptar',
        onPrincipal: () => Navigator.pop(ctx, true),
        textoSecundario: 'Rechazar',
        onSecundario: () => Navigator.pop(ctx, false),
      ),
    );
    if (aceptar != null && mounted) {
      try {
        await TripService.responderPlazo(widget.tripId, aceptar: aceptar);
        if (mounted) _snack(aceptar ? 'Nuevo horario aceptado' : 'Tu reserva vuelve a recibir ofertas');
      } on ApiException catch (e) {
        if (mounted) _snack(e.message);
      } catch (e) {
        if (mounted) _snack(mensajeDeError(e));
      }
    }
    _dialogoPlazoAbierto = false;
    if (mounted) await _load();
  }

  static bool _estaActivo(String? estado) =>
      estado != null &&
      !const {TripStatus.reservado, TripStatus.finalizado, TripStatus.cancelado, TripStatus.disputa, TripStatus.enDisputa}.contains(estado);

  void _abrirRastreo() {
    _sondeo?.cancel();
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RastreoScreen()));
  }

  Future<void> _aceptarOferta(Map<String, dynamic> oferta) async {
    final id = (oferta['_id'] ?? oferta['id'])?.toString();
    if (id == null || _aceptandoId != null) return;
    setState(() => _aceptandoId = id);
    try {
      await OfferService.acceptOffer(widget.tripId, id);
      if (!mounted) return;
      _snack('Conductor asignado a tu reserva');
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      _snack(e.message);
      if (e.statusCode == 404 || e.statusCode == 409 || e.statusCode == 422) {
        setState(() => _ofertas = _ofertas.where((o) => (o['_id'] ?? o['id'])?.toString() != id).toList());
      }
    } catch (e) {
      if (mounted) _snack(mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _aceptandoId = null);
    }
  }

  /// Error de carga distinto de 404 (red, 5xx...): se ofrece reintentar.
  String? _error;

  Future<void> _load() async {
    if (mounted && !_loading) setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiClient.instance.getTripDetail(widget.tripId);
      final reportado = await ReportService.yaReportado(widget.tripId);
      // El servidor manda yaCalificado; el recuerdo local cubre el caso en que
      // la respuesta no lo traiga.
      final calificado = data['yaCalificado'] == true || await TripService.yaCalificado(widget.tripId);
      if (mounted) {
        setState(() {
          _trip = data;
          _rated = _rated || calificado;
          _reportado = _reportado || reportado;
          _loading = false;
          _error = null;
        });
        _ajustarSondeo();
        _revisarPlazo();
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.statusCode == 404 ? null : e.message;
      });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = mensajeDeError(e); });
    }
  }

  Future<void> _calificar() async {
    if (_rating == 0 || _rated) return;
    try {
      await ApiClient.instance.rateTrip(widget.tripId, _rating);
      if (mounted) {
        setState(() => _rated = true);
        _snack('Calificación guardada');
      }
    } catch (e) {
      if (mounted) _snack('Error: ${e.toString().replaceFirst("Exception: ", "")}');
    }
  }

  bool _cancelando = false;

  /// La reserva (`reservado`) no sale en /trips/active, así que el rastreo
  /// no la abre: se cancela desde aquí (reservado -> cancelado está permitido).
  Future<void> _cancelarReserva() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const CancelTripScreen(enCurso: false)),
    );
    final motivo = motivoDesdeResultado(result);
    if (motivo == null || !mounted) return;
    setState(() => _cancelando = true);
    try {
      await TripService.cancelTrip(widget.tripId, motivo: motivo);
      if (!mounted) return;
      _snack('Reserva cancelada');
      await _load();
    } catch (e) {
      if (mounted) _snack(mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _cancelando = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// Se cuenta desde que el conductor cerró el viaje (`completadoAt`); si no
  /// viene, desde `finalizadoAt`.
  bool get _dentroDelPlazoParaReportar {
    final iso = (_trip?['completadoAt'] ?? _trip?['finalizadoAt']) as String?;
    final cierre = iso == null ? null : DateTime.tryParse(iso);
    if (cierre == null || _trip?['estado'] == 'cancelado') return false;
    return DateTime.now().difference(cierre).inMinutes < ViajeDetalleScreen.minutosParaReportar;
  }

  Future<void> _reportarCliente() async {
    final trip = _trip;
    if (trip == null || _reportado) return;
    final enviado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ReportarClienteScreen(trip: trip)),
    );
    // Aunque el usuario vuelva sin enviar, pudo recibir un 409 ("ya
    // reportaste"): ReportService lo deja marcado y aquí se refleja.
    final reportado = enviado == true || await ReportService.yaReportado(widget.tripId);
    if (!mounted || !reportado) return;
    setState(() => _reportado = true);
    if (enviado == true) _snack('Reporte enviado. Un administrador lo revisará.');
  }

  String _estadoLabel(String estado) {
    switch (estado) {
      case 'buscando_conductor': return 'Buscando conductor';
      case 'reservado': return _trip?['conductor'] != null ? 'Reserva con conductor asignado' : 'Reservado';
      case 'aceptado': return 'Aceptado';
      case 'en_curso': return 'En curso';
      case 'esperando_confirmacion': return 'Esperando confirmación';
      case 'finalizado': return 'Finalizado';
      case 'cancelado': return etiquetaCancelacion(_trip?['motivoCancelacion'] as String?);
      default: return TripStatus.label(estado);
    }
  }

  Color _estadoColor(String estado) {
    switch (estado) {
      case 'buscando_conductor': return const Color(0xFFFF9800);
      case 'reservado': return const Color(0xFF9E9E9E);
      case 'aceptado': return const Color(0xFF1E88E5);
      case 'en_curso': return const Color(0xFF1565C0);
      case 'esperando_confirmacion':
      case 'finalizado': return const Color(0xFF4CAF50);
      case 'cancelado': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day}/${dt.month}/${dt.year} ${hora12(dt)}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Color(0xFF1A1A2E)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Detalle del viaje', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _trip == null && _error != null
              ? ErrorCarga(titulo: 'No pudimos cargar el viaje', detalle: _error, onReintentar: _load)
          : _trip == null
              ? const Center(child: Text('Viaje no encontrado', style: TextStyle(color: Colors.black45)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatusSection(),
                      const SizedBox(height: 16),
                      _buildRouteSection(),
                      const SizedBox(height: 16),
                      _buildInfoSection(),
                      if (widget.comoConductor) ...[
                        if (_trip!['estado'] == 'finalizado') ...[
                          const SizedBox(height: 16),
                          _buildGananciasSection(),
                        ],
                        if (_trip!['cliente'] != null) ...[
                          const SizedBox(height: 16),
                          _buildClienteSection(),
                        ],
                      ] else if (_trip!['conductor'] != null) ...[
                        const SizedBox(height: 16),
                        _buildConductorSection(),
                      ] else if (_reservaSinConductor) ...[
                        const SizedBox(height: 16),
                        _buildOfertasReservaSection(),
                      ],
                      if (!widget.comoConductor && _trip!['estado'] == TripStatus.reservado) ...[
                        const SizedBox(height: 16),
                        BotonSecundario(
                          texto: 'Cancelar reserva',
                          icono: Icons.event_busy_outlined,
                          color: ColoresApp.rojo,
                          cargando: _cancelando,
                          onPressed: _cancelando ? null : _cancelarReserva,
                        ),
                      ],
                      if (!widget.comoConductor && _trip!['estado'] == 'finalizado' && !_rated) ...[
                        const SizedBox(height: 16),
                        _buildRatingSection(),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _buildStatusSection() {
    final estado = _trip!['estado'] as String? ?? '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _estadoColor(estado).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _estadoColor(estado).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.circle, color: _estadoColor(estado), size: 12),
              const SizedBox(width: 8),
              Expanded(child: Text(_estadoLabel(estado), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _estadoColor(estado)))),
            ],
          ),
          const SizedBox(height: 8),
          if (_trip!['tipoProgramacion'] == 'programada') _reservaRow(),
          _timestampRow('Creado', _trip!['createdAt'] as String?),
          _timestampRow('Aceptado', _trip!['aceptadoAt'] as String?),
          _timestampRow('En curso', _trip!['enCursoAt'] as String?),
          _timestampRow('Completado', _trip!['completadoAt'] as String?),
          _timestampRow('Finalizado', _trip!['finalizadoAt'] as String?),
          if (_trip!['canceladoAt'] != null) _timestampRow('Cancelado', _trip!['canceladoAt'] as String?),
        ],
      ),
    );
  }

  Widget _reservaRow() {
    final fecha = _trip!['fechaProgramada'] as String?;
    final hora = _trip!['horaProgramada'] as String?;
    if (fecha == null || hora == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const SizedBox(width: 20),
          const Text('Programado para: ', style: TextStyle(fontSize: 12, color: Colors.black45)),
          Expanded(child: Text('$fecha $hora', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _timestampRow(String label, String? iso) {
    if (iso == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          const SizedBox(width: 20),
          Text('$label: ', style: const TextStyle(fontSize: 12, color: Colors.black45)),
          Text(_formatDate(iso), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildRouteSection() {
    final origen = _trip!['origen'] as Map<String, dynamic>?;
    final destino = _trip!['destino'] as Map<String, dynamic>?;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ruta', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black45)),
          const SizedBox(height: 10),
          Row(children: [
            Column(children: [
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF1E88E5), shape: BoxShape.circle)),
              Container(width: 1.5, height: 20, color: Colors.grey.shade300),
              Container(width: 8, height: 8, decoration: BoxDecoration(border: Border.all(color: const Color(0xFF4CAF50), width: 2), shape: BoxShape.circle)),
            ]),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(origen?['direccion'] as String? ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 14),
              Text(destino?['direccion'] as String? ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ])),
          ]),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Información', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black45)),
          const SizedBox(height: 10),
          if (_trip!['descripcion'] != null && (_trip!['descripcion'] as String).isNotEmpty)
            _infoRow('Carga', _trip!['descripcion'] as String),
          if (_trip!['tipoVehiculoRequerido'] != null)
            _infoRow('Vehículo pedido', _trip!['tipoVehiculoRequerido'] as String),
          if (_trip!['receptorNombre'] != null)
            _infoRow('Recibe', _trip!['receptorNombre'] as String),
          if (_trip!['receptorTelefono'] != null)
            _infoRow('Teléfono de quien recibe', _trip!['receptorTelefono'] as String),
          _infoRow('Precio estimado', formatearPesos(_trip!['precioEstimado'] as num?)),
          _infoRow('Precio final', formatearPesos(_trip!['precioFinal'] as num?)),
          if (_trip!['motivoCancelacion'] != null)
            _infoRow('Motivo cancelación', _trip!['motivoCancelacion'] as String),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: Colors.black45))),
          const SizedBox(width: 8),
          Flexible(child: Text(value, textAlign: TextAlign.end, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _buildConductorSection() {
    final conductor = _trip!['conductor'] as Map<String, dynamic>?;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Conductor', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black45)),
          const SizedBox(height: 10),
          Row(children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFFE0E0E0),
              child: Text(
                _initials(conductor!['nombre'] as String? ?? ''),
                style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(conductor['nombre'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(_vehiculoTexto(conductor), style: const TextStyle(fontSize: 12, color: Colors.black45)),
            ])),
          ]),
          if (_esReserva) ..._reservaConductorExtra(conductor),
        ],
      ),
    );
  }

  /// Reserva asignada: solo chat. La ubicación y el teléfono llegan con el
  /// rastreo, cuando el servidor la active 45 min antes de la recogida.
  List<Widget> _reservaConductorExtra(Map<String, dynamic> conductor) {
    final veh = conductor['vehiculo'] as Map<String, dynamic>?;
    final placa = (veh?['placa'] ?? conductor['placa'])?.toString() ?? '';
    return [
      const SizedBox(height: 10),
      Row(children: [
        const Icon(Icons.star_rounded, color: ColoresApp.ambar, size: 16),
        const SizedBox(width: 4),
        Text(etiquetaCalificacionConductor(conductor),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ColoresApp.textoOscuro)),
        const Spacer(),
        if (placa.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: ColoresApp.placaFondo,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: ColoresApp.placaTexto),
            ),
            child: Text(placa.toUpperCase(),
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: ColoresApp.placaTexto, letterSpacing: 1, fontFeatures: cifrasTabulares)),
          ),
      ]),
      const SizedBox(height: 10),
      const Text('Verás su ubicación 45 min antes de la recogida.', style: TextStyle(fontSize: 12, color: Colors.black45)),
      const SizedBox(height: 12),
      BotonPrincipal(
        key: const Key('reserva_chat'),
        texto: 'Chat con el conductor',
        icono: Icons.chat_bubble_outline_rounded,
        alto: 44,
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(trip: _trip!))),
      ),
    ];
  }

  Widget _buildOfertasReservaSection() {
    return _tarjeta('Ofertas para tu reserva', [
      if (_ofertas.isEmpty)
        const Text('Todavía no hay ofertas. Te avisamos cuando llegue una.', style: TextStyle(fontSize: 13, color: Colors.black45))
      else
        for (final o in _ofertas) _ofertaRow(o),
    ]);
  }

  Widget _ofertaRow(Map<String, dynamic> o) {
    final id = (o['_id'] ?? o['id'])?.toString();
    final conductor = o['conductor'] as Map<String, dynamic>? ?? const {};
    final monto = num.tryParse(o['monto']?.toString() ?? '') ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(conductor['nombre'] as String? ?? 'Conductor', style: const TextStyle(fontWeight: FontWeight.w600)),
          Text('${_vehiculoTexto(conductor)} - ${etiquetaCalificacionConductor(conductor)}',
              style: const TextStyle(fontSize: 12, color: Colors.black45)),
          Text(formatearPesos(monto),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ColoresApp.textoOscuro, fontFeatures: cifrasTabulares)),
        ])),
        const SizedBox(width: 8),
        SizedBox(
          width: 100,
          child: BotonPrincipal(
            key: Key('reserva_aceptar_$id'),
            texto: 'Aceptar',
            alto: 40,
            cargando: _aceptandoId == id,
            onPressed: _aceptandoId == null ? () => _aceptarOferta(o) : null,
          ),
        ),
      ]),
    );
  }

  Widget _buildGananciasSection() {
    final precio = (_trip!['precioFinal'] ?? _trip!['precioEstimado']) as num? ?? 0;
    // Comisión de la plataforma: 10 % del precio final (misma regla del backend).
    final comision = (precio * 0.1 * 100).round() / 100;
    return _tarjeta('Tus ganancias', [
      _infoRow('Precio del viaje', formatearPesos(precio)),
      _infoRow('Comisión (10 %)', '- ${formatearPesos(comision)}'),
      const Divider(height: 16),
      _infoRow('Ganancia neta', formatearPesos(precio - comision)),
    ]);
  }

  Widget _buildClienteSection() {
    final cliente = _trip!['cliente'] as Map<String, dynamic>;
    final nombre = cliente['nombre'] as String? ?? '';
    final Widget accion;
    if (_reportado) {
      accion = const Row(children: [
        Icon(Icons.check_circle_outline, size: 16, color: Colors.black45),
        SizedBox(width: 6),
        Expanded(child: Text('Ya reportaste este viaje', style: TextStyle(fontSize: 13, color: Colors.black45))),
      ]);
    } else if (_dentroDelPlazoParaReportar) {
      accion = SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _reportarCliente,
          icon: const Icon(Icons.flag_outlined, size: 18),
          label: const Text('Reportar cliente', style: TextStyle(fontWeight: FontWeight.w600)),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFEF4444),
            side: const BorderSide(color: Color(0xFFFECACA)),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );
    } else {
      accion = const Text(
        'Puedes reportar hasta ${ViajeDetalleScreen.minutosParaReportar} minutos después de cerrar el viaje. '
        'Si necesitas ayuda, escribe a soporte.',
        style: TextStyle(fontSize: 12, color: Colors.black45),
      );
    }
    return _tarjeta('Cliente', [
      Row(children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: const Color(0xFFE0E0E0),
          child: Text(_initials(nombre), style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(nombre, style: const TextStyle(fontWeight: FontWeight.w600))),
      ]),
      const SizedBox(height: 12),
      accion,
    ]);
  }

  Widget _tarjeta(String titulo, List<Widget> hijos) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black45)),
          const SizedBox(height: 10),
          ...hijos,
        ],
      ),
    );
  }

  String _vehiculoTexto(Map<String, dynamic> conductor) {
    // Tolerante a dos formas: `tipoVehiculo`/`placa` planos o
    // anidados en `vehiculo: {tipo, placa}` (forma usada en ofertas).
    final veh = conductor['vehiculo'] as Map<String, dynamic>?;
    final tipo = (veh?['tipo'] ?? conductor['tipoVehiculo'])?.toString() ?? '';
    final placa = (veh?['placa'] ?? conductor['placa'])?.toString() ?? '';
    if (tipo.isEmpty && placa.isEmpty) return '';
    return [tipo, placa].where((s) => s.isNotEmpty).join(' · ');
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  Widget _buildRatingSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Calificar viaje', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black45)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final star = i + 1;
              return IconButton(
                icon: Icon(star <= _rating ? Icons.star_rounded : Icons.star_border_rounded, color: const Color(0xFFFFC107), size: 36),
                onPressed: () => setState(() => _rating = star),
              );
            }),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _rating > 0 ? _calificar : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A3C6E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('Enviar calificación', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
