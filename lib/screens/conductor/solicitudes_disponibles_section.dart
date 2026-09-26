import 'dart:async';

import 'package:flutter/material.dart';

import '../../contracts/cierre.dart' show distanciaKm;
import '../../contracts/solicitud.dart';
import '../../models/oferta_pendiente.dart' show formatoCuentaRegresiva;
import '../../services/api_client.dart';
import '../../services/driver_location_service.dart';
import '../../services/server_clock.dart';
import '../../services/solicitudes_disponibles_service.dart';
import 'conductor_trip_detail_screen.dart';
import 'offers_screen.dart';

/// Abre el detalle de la solicitud para ofertar, confirmando antes con el
/// backend que sigue abierta (GET /api/trips/:id).
Future<void> abrirDetalleSolicitud(BuildContext context, String tripId) async {
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  try {
    final detail = await ApiClient.instance.getTripDetail(tripId);
    if (!context.mounted) return;
    if (!solicitudSigueAbierta(detail['estado'])) {
      SolicitudesDisponiblesService.instance.quitar(tripId);
      messenger.showSnackBar(const SnackBar(content: Text('Este viaje ya no está disponible')));
      return;
    }
    final tripData = Map<String, dynamic>.from(detail);
    tripData['id'] ??= tripId;
    await navigator.push(MaterialPageRoute(builder: (_) => ConductorTripDetailScreen(trip: tripData)));
  } catch (e) {
    messenger.showSnackBar(SnackBar(
      content: Text('Error al cargar el viaje: ${e.toString().replaceFirst("Exception: ", "")}'),
    ));
  }
}

/// "Solicitudes disponibles" del conductor: lista viva de
/// [SolicitudesDisponiblesService] con precio, distancia a la recogida,
/// origen → destino, carga, tiempo restante y el estado de la oferta propia.
class SolicitudesDisponiblesSection extends StatefulWidget {
  /// Conductor en línea (si no, se invita a conectarse).
  final bool online;

  /// Cambiando el estado de conexión (deshabilita "Conectarme").
  final bool cargandoConexion;

  /// Botón "Conectarme" del estado desconectado (null: sin botón).
  final VoidCallback? onConectar;

  /// Máximo de tarjetas a mostrar (null: todas). Si hay más, aparece
  /// "Ver todas" con [onVerTodas].
  final int? maximo;
  final VoidCallback? onVerTodas;

  /// Encabezado "Solicitudes disponibles" (falso dentro de la pantalla propia).
  final bool mostrarEncabezado;

  const SolicitudesDisponiblesSection({
    super.key,
    required this.online,
    this.cargandoConexion = false,
    this.onConectar,
    this.maximo,
    this.onVerTodas,
    this.mostrarEncabezado = true,
  });

  @override
  State<SolicitudesDisponiblesSection> createState() => _SolicitudesDisponiblesSectionState();
}

class _SolicitudesDisponiblesSectionState extends State<SolicitudesDisponiblesSection> {
  static const Color _accentBlue = Color(0xFF2563EB);
  static const Color _textDark = Color(0xFF1A1A2E);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _textGrey = Color(0xFF757575);
  static const Color _accentGreen = Color(0xFF4CAF50);

  StreamSubscription<List<SolicitudDisponible>>? _sub;
  Timer? _reloj;
  List<SolicitudDisponible> _lista = const [];
  bool _refrescando = false;

  @override
  void initState() {
    super.initState();
    _lista = SolicitudesDisponiblesService.instance.solicitudes;
    _sub = SolicitudesDisponiblesService.instance.cambios.listen((l) {
      if (mounted) setState(() => _lista = l);
    });
    // Cuentas regresivas (tiempo restante de la solicitud y de la oferta).
    _reloj = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _lista.isNotEmpty) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _reloj?.cancel();
    super.dispose();
  }

  Future<void> _refrescar() async {
    if (_refrescando) return;
    setState(() => _refrescando = true);
    try {
      await SolicitudesDisponiblesService.instance.sincronizar();
    } finally {
      if (mounted) setState(() => _refrescando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibles = widget.maximo == null ? _lista : _lista.take(widget.maximo!).toList();
    final ocultas = _lista.length - visibles.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.mostrarEncabezado) ...[
          _encabezado(ocultas),
          const SizedBox(height: 10),
        ],
        if (!widget.online)
          _tarjetaEstado(
            icono: Icons.power_settings_new_rounded,
            color: _textGrey,
            titulo: 'Estás desconectado',
            detalle: 'Conéctate para empezar a recibir envíos.',
            accion: widget.onConectar == null
                ? null
                : ElevatedButton(
                    onPressed: widget.cargandoConexion ? null : widget.onConectar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Conectarme'),
                  ),
          )
        else if (visibles.isEmpty)
          _tarjetaEstado(
            key: const Key('esperando_solicitudes'),
            icono: Icons.radar_rounded,
            color: _accentBlue,
            titulo: 'Esperando solicitudes',
            detalle: 'Te avisaremos al instante cuando haya un envío cerca de ti. '
                'Las solicitudes abiertas aparecerán aquí aunque cierres el aviso.',
          )
        else
          for (var i = 0; i < visibles.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            SolicitudDisponibleCard(
              key: Key('solicitud_${visibles[i].id}'),
              solicitud: visibles[i],
              onVer: () => abrirDetalleSolicitud(context, visibles[i].id),
              onVerOferta: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OffersScreen()),
              ),
            ),
          ],
        if (widget.online && ocultas > 0 && widget.onVerTodas != null) ...[
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: widget.onVerTodas,
            style: OutlinedButton.styleFrom(
              foregroundColor: _accentBlue,
              side: BorderSide(color: _accentBlue.withValues(alpha: 0.4)),
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text('Ver todas las solicitudes (${_lista.length})',
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ],
    );
  }

  Widget _encabezado(int ocultas) {
    final total = _lista.length;
    // El título va en un Expanded (antes un Flexible y un Spacer se repartían
    // el ancho a medias y el título salía cortado: "Solicitudes dispon…").
    return Row(
      children: [
        const Icon(Icons.inbox_rounded, color: _accentBlue, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            children: [
              const Flexible(
                child: Text('Solicitudes disponibles',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _textDark),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              if (widget.online && total > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: _accentBlue, borderRadius: BorderRadius.circular(12)),
                  child: Text('$total',
                      key: const Key('solicitudes_total'),
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                ),
              ],
            ],
          ),
        ),
        if (widget.online)
          IconButton(
            key: const Key('refrescar_solicitudes'),
            tooltip: 'Actualizar',
            visualDensity: VisualDensity.compact,
            onPressed: _refrescando ? null : _refrescar,
            icon: _refrescando
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh_rounded, color: _textSecondary),
          ),
      ],
    );
  }

  Widget _tarjetaEstado({
    Key? key,
    required IconData icono,
    required Color color,
    required String titulo,
    required String detalle,
    Widget? accion,
  }) {
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icono, color: color, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _textDark)),
                const SizedBox(height: 4),
                Text(detalle, style: const TextStyle(fontSize: 13, color: _textSecondary, height: 1.4)),
              ],
            ),
          ),
          if (accion != null) ...[const SizedBox(width: 8), accion],
        ],
      ),
    );
  }
}

/// Tarjeta de una solicitud disponible.
class SolicitudDisponibleCard extends StatelessWidget {
  final SolicitudDisponible solicitud;
  final VoidCallback onVer;
  final VoidCallback onVerOferta;

  const SolicitudDisponibleCard({
    super.key,
    required this.solicitud,
    required this.onVer,
    required this.onVerOferta,
  });

  static const Color _primaryBlue = Color(0xFF1A3C6E);
  static const Color _accentBlue = Color(0xFF2563EB);
  static const Color _lightBlue = Color(0xFFEFF6FF);
  static const Color _green = Color(0xFF16A34A);
  static const Color _orange = Color(0xFFEA580C);
  static const Color _textDark = Color(0xFF1A1A2E);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _bgLight = Color(0xFFF5F7FA);

  static num? _num(dynamic v) => v == null ? null : num.tryParse(v.toString());

  static String dinero(num? v) {
    if (v == null) return '—';
    final s = v.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
    return '\$ $s';
  }

  static String _direccion(dynamic v) {
    if (v is String) return v;
    if (v is Map) return (v['direccion']?.toString()) ?? '';
    return '';
  }

  /// Km hasta la recogida: desde el GPS actual si se conoce; si no, la
  /// `distancia` que calculó el backend con la última ubicación guardada.
  /// El backend manda `distancia: 0` cuando no pudo calcularla (sin
  /// ubicación guardada): en ese caso no se conoce y no se muestra nada.
  static double? kmHastaRecogida(Map<String, dynamic> viaje, double? lat, double? lng) {
    final origen = viaje['origen'];
    if (origen is Map && lat != null && lng != null) {
      final oLat = _num(origen['lat'])?.toDouble();
      final oLng = _num(origen['lng'])?.toDouble();
      if (oLat != null && oLng != null && !(oLat == 0 && oLng == 0)) return distanciaKm(lat, lng, oLat, oLng);
    }
    final backend = _num(viaje['distancia'])?.toDouble();
    return (backend == null || backend <= 0) ? null : backend;
  }

  static String formatoKm(double km) => km < 10 ? '${km.toStringAsFixed(1)} km' : '${km.round()} km';

  @override
  Widget build(BuildContext context) {
    final v = solicitud.viaje;
    final ahora = ServerClock.ahora();
    final precio = _num(v['precioEstimado']) ?? _num(v['precioCliente']);
    final origen = _direccion(v['origen']);
    final destino = _direccion(v['destino']);
    final carga = (v['descripcion'] ?? v['carga'])?.toString().trim() ?? '';
    final minutos = _num(v['tiempoEstimado'])?.toInt();
    final km = kmHastaRecogida(v, DriverLocationService.instance.lastLat, DriverLocationService.instance.lastLng);
    final restante = segundosRestantesSolicitud(v, ahora);
    final programada = v['tipoProgramacion'] == 'programada';
    final oferta = solicitud.oferta;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: oferta != null ? Border.all(color: _accentBlue.withValues(alpha: 0.35)) : null,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Precio propuesto por el cliente',
                        style: TextStyle(fontSize: 11, color: _textSecondary)),
                    Text(dinero(precio),
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: _green, letterSpacing: -0.5)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (programada)
                _chip(Icons.event_rounded, 'Reserva', color: _primaryBlue)
              else if (restante > 0)
                _chip(
                  Icons.timer_outlined,
                  formatoCuentaRegresiva(Duration(seconds: restante)),
                  color: restante <= 60 ? Colors.red : _orange,
                )
              else
                _chip(Icons.timer_off_outlined, 'Por vencer', color: Colors.red),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (km != null) _chip(Icons.near_me_rounded, textoDistanciaRecogida(km)),
              if (minutos != null && minutos > 0) _chip(Icons.schedule_rounded, '$minutos min de viaje'),
            ],
          ),
          const SizedBox(height: 14),
          _parada(Icons.circle, _green, 'Recogida', origen.isEmpty ? 'Cerca de ti' : origen),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(width: 2, height: 14, color: Colors.grey.shade300),
            ),
          ),
          _parada(Icons.location_on_rounded, Colors.red, 'Destino', destino.isEmpty ? 'Cargando…' : destino),
          if (carga.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: _bgLight, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const Icon(Icons.inventory_2_outlined, size: 18, color: _textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(carga,
                      style: const TextStyle(color: _textDark, fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 14),
          if (oferta != null) ...[
            Container(
              key: const Key('oferta_enviada'),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: _lightBlue, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const Icon(Icons.send_rounded, size: 18, color: _accentBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _textoOferta(oferta.monto, oferta.restante(ahora)),
                    style: const TextStyle(color: _accentBlue, fontSize: 13, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: onVerOferta,
              style: OutlinedButton.styleFrom(
                foregroundColor: _accentBlue,
                side: BorderSide(color: _accentBlue.withValues(alpha: 0.5)),
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Ver mi oferta', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ] else ...[
            if (solicitud.ofertaRechazada) ...[
              Row(
                key: const Key('oferta_rechazada'),
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: _orange),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text('El cliente rechazó tu oferta anterior. Puedes enviar una nueva.',
                        style: TextStyle(fontSize: 12, color: _orange, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            ElevatedButton(
              onPressed: onVer,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentBlue,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Ver y ofertar', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            ),
          ],
        ],
      ),
    );
  }

  static String _textoOferta(num monto, Duration? restante) {
    final base = 'Oferta enviada · ${dinero(monto)}';
    if (restante == null) return '$base · esperando al cliente';
    return '$base · vence en ${formatoCuentaRegresiva(restante)}';
  }

  Widget _chip(IconData icon, String texto, {Color color = _accentBlue}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(texto, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ]),
      );

  Widget _parada(IconData icon, Color color, String titulo, String texto) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(titulo, style: const TextStyle(fontSize: 11, color: _textSecondary)),
              Text(texto,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _textDark),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ]),
          ),
        ],
      );
}
