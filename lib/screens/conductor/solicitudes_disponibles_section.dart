import 'dart:async';

import 'package:flutter/material.dart';

import '../../contracts/cierre.dart' show distanciaKm;
import '../../contracts/solicitud.dart';
import '../../models/oferta_pendiente.dart' show formatoCuentaRegresiva;
import '../../services/api_client.dart';
import '../../services/driver_location_service.dart';
import '../../services/server_clock.dart';
import '../../services/solicitudes_disponibles_service.dart';
import '../../widgets/vehiculo_mapa.dart' show TipoVehiculoMapa, tipoVehiculoMapaDe;
import 'conductor_trip_detail_screen.dart';
import 'offers_screen.dart';
import '../../core/formato_dinero.dart';
import '../shared/ui_compartida.dart';

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
            color: ColoresApp.textoSecundario,
            titulo: 'Estás desconectado',
            detalle: 'Conéctate para empezar a recibir envíos.',
            accion: widget.onConectar == null
                ? null
                : ElevatedButton(
                    onPressed: widget.cargandoConexion ? null : widget.onConectar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ColoresApp.verde,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Conectarme', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
          )
        else if (visibles.isEmpty)
          _tarjetaEstado(
            key: const Key('esperando_solicitudes'),
            icono: Icons.radar_rounded,
            color: ColoresApp.azul,
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
              foregroundColor: ColoresApp.azul,
              side: BorderSide(color: ColoresApp.azul.withValues(alpha: 0.4)),
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
        const Icon(Icons.inbox_rounded, color: ColoresApp.azul, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            children: [
              const Flexible(
                child: Text('Solicitudes disponibles',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ColoresApp.textoOscuro),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              if (widget.online && total > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: ColoresApp.azul, borderRadius: BorderRadius.circular(12)),
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
                : const Icon(Icons.refresh_rounded, color: ColoresApp.textoSecundario),
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
    // El botón va debajo del texto: al lado dejaba la columna tan angosta que
    // el título se partía ("Estás desc/onectado").
    return TarjetaBlanca(
      key: key,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
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
                    Text(titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ColoresApp.textoOscuro)),
                    const SizedBox(height: 4),
                    Text(detalle, style: const TextStyle(fontSize: 13, color: ColoresApp.textoSecundario, height: 1.4)),
                  ],
                ),
              ),
            ],
          ),
          if (accion != null) ...[const SizedBox(height: 14), accion],
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


  static num? _num(dynamic v) => v == null ? null : num.tryParse(v.toString());

  static String dinero(num? v) => formatearPesos(v, siNulo: '—');

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
    final vehiculoRequerido = v['tipoVehiculoRequerido']?.toString().trim();
    final oferta = solicitud.oferta;

    final tieneVehiculo = vehiculoRequerido != null && vehiculoRequerido.isNotEmpty;

    return TarjetaBlanca(
      colorBorde: oferta != null ? ColoresApp.azul.withValues(alpha: 0.5) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (tieneVehiculo) _badge(vehiculoRequerido, _colorVehiculo(vehiculoRequerido)),
              const Spacer(),
              if (programada)
                _chip(Icons.event_rounded, 'Reserva', color: ColoresApp.azulOscuro)
              else if (restante > 0)
                _chip(
                  Icons.timer_outlined,
                  formatoCuentaRegresiva(Duration(seconds: restante)),
                  color: restante <= 60 ? ColoresApp.rojo : ColoresApp.naranja,
                )
              else
                _chip(Icons.timer_off_outlined, 'Por vencer', color: ColoresApp.rojo),
            ],
          ),
          if (km != null || (minutos != null && minutos > 0)) ...[
            const SizedBox(height: 8),
            Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 5, children: [
              const Icon(Icons.near_me_rounded, size: 14, color: ColoresApp.textoSecundario),
              if (km != null) Text(textoDistanciaRecogida(km), style: _estiloDato),
              if (km != null && minutos != null && minutos > 0) const Text('·', style: _estiloDato),
              if (minutos != null && minutos > 0) Text('$minutos min de viaje', style: _estiloDato),
            ]),
          ],
          const SizedBox(height: 12),
          _parada(ColoresApp.verde, 'Recoge', origen.isEmpty ? 'Cerca de ti' : origen),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(width: 2, height: 16, color: ColoresApp.borde),
            ),
          ),
          _parada(ColoresApp.rojo, 'Entrega', destino.isEmpty ? 'Cargando…' : destino),
          if (carga.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.inventory_2_outlined, size: 16, color: ColoresApp.textoSecundario),
              const SizedBox(width: 8),
              Expanded(
                child: Text(carga,
                    style: const TextStyle(color: ColoresApp.textoSecundario, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
          ],
          const SizedBox(height: 12),
          const Divider(height: 1, thickness: 1, color: ColoresApp.divisor),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(dinero(precio),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: ColoresApp.textoOscuro, fontFeatures: cifrasTabulares)),
              ),
              if (oferta == null)
                ElevatedButton(
                  onPressed: onVer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColoresApp.azul,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(112, 44),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Ofertar', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                ),
            ],
          ),
          if (oferta != null) ...[
            const SizedBox(height: 12),
            Container(
              key: const Key('oferta_enviada'),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: ColoresApp.azulTenue, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const Icon(Icons.send_rounded, size: 18, color: ColoresApp.azul),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _textoOferta(oferta.monto, oferta.restante(ahora)),
                    style: const TextStyle(color: ColoresApp.azul, fontSize: 13, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: onVerOferta,
              style: OutlinedButton.styleFrom(
                foregroundColor: ColoresApp.azul,
                side: BorderSide(color: ColoresApp.azul.withValues(alpha: 0.5)),
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Ver mi oferta', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ] else if (solicitud.ofertaRechazada) ...[
            const SizedBox(height: 10),
            Row(
              key: const Key('oferta_rechazada'),
              children: [
                const Icon(Icons.info_outline_rounded, size: 16, color: ColoresApp.naranja),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text('El cliente rechazó tu oferta anterior. Puedes enviar una nueva.',
                      style: TextStyle(fontSize: 12, color: ColoresApp.naranja, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static const _estiloDato = TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ColoresApp.textoSecundario);

  /// Color del distintivo según el tipo de vehículo pedido (misma clasificación
  /// que el dibujo del mapa).
  static Color _colorVehiculo(String tipo) => switch (tipoVehiculoMapaDe(tipo)) {
        TipoVehiculoMapa.camioneta => ColoresApp.azul,
        TipoVehiculoMapa.carro => ColoresApp.verde,
        TipoVehiculoMapa.furgon => ColoresApp.naranja,
        _ => ColoresApp.azulOscuro,
      };

  Widget _badge(String texto, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
        child: Text(texto, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
      );

  static String _textoOferta(num monto, Duration? restante) {
    final base = 'Oferta enviada · ${dinero(monto)}';
    if (restante == null) return '$base · esperando al cliente';
    return '$base · vence en ${formatoCuentaRegresiva(restante)}';
  }

  Widget _chip(IconData icon, String texto, {Color color = ColoresApp.azul}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(texto, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ]),
      );

  Widget _parada(Color color, String titulo, String texto) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(titulo, style: const TextStyle(fontSize: 11, color: ColoresApp.textoSecundario)),
              Text(texto,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ColoresApp.textoOscuro),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ]),
          ),
        ],
      );
}
