import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../contracts/trip_status.dart';
import '../../models/trip.dart';
import '../../services/api_client.dart';
import '../../services/api/http_client.dart' show ApiException;
import '../../services/driver_location_service.dart';
import '../../services/ruta_viaje_service.dart';
import '../../widgets/mapa_viaje.dart';
import 'trip_chat_screen.dart';
import 'viaje_aceptado_screen.dart';
import 'trip_in_progress_screen.dart';

class ClienteData {
  final String nombre;
  final double rating;
  final String? avatarUrl;
  const ClienteData({
    required this.nombre,
    required this.rating,
    this.avatarUrl,
  });
}

class OfertaAceptadaScreen extends StatefulWidget {
  final String montoOferta;
  final ClienteData cliente;
  final String origen;
  final String destino;
  final String distancia;
  final String descripcionCarga;
  final Map<String, dynamic> trip;

  const OfertaAceptadaScreen({
    super.key,
    this.montoOferta = '—',
    this.cliente = const ClienteData(nombre: 'Cliente', rating: 5.0),
    this.origen = 'Origen',
    this.destino = 'Destino',
    this.distancia = '—',
    this.descripcionCarga = 'No especificada',
    required this.trip,
  });

  /// Pantalla con los datos reales del viaje (GET /api/trips/:id) y el monto
  /// ya formateado de la oferta aceptada.
  factory OfertaAceptadaScreen.desdeViaje(Map<String, dynamic> trip, {required String montoOferta, Key? key}) {
    final cliente = trip['cliente'] is Map ? Map<String, dynamic>.from(trip['cliente'] as Map) : const <String, dynamic>{};
    final origen = trip['origen'] is Map ? trip['origen'] as Map : null;
    final destino = trip['destino'] is Map ? trip['destino'] as Map : null;
    return OfertaAceptadaScreen(
      key: key,
      montoOferta: montoOferta,
      cliente: ClienteData(
        nombre: cliente['nombre'] as String? ?? 'Cliente',
        rating: (cliente['rating'] as num?)?.toDouble() ?? 5.0,
        avatarUrl: cliente['avatar'] as String?,
      ),
      origen: origen?['direccion'] as String? ?? 'Origen',
      destino: destino?['direccion'] as String? ?? 'Destino',
      distancia: trip['distancia'] != null ? '${trip['distancia']} km' : '—',
      descripcionCarga: trip['descripcion'] as String? ?? 'No especificada',
      trip: trip,
    );
  }

  @override
  State<OfertaAceptadaScreen> createState() => _OfertaAceptadaScreenState();
}

class _OfertaAceptadaScreenState extends State<OfertaAceptadaScreen> {
  bool _starting = false;
  bool _cancelling = false;

  /// Ruta conductor → recogida calculada por el backend (si ya existe).
  List<LatLng>? _ruta;
  bool _rutaAproximada = false;

  /// Id del viaje en cualquiera de los formatos del backend (`_id`/`id` del
  /// detalle, `viajeId`/`tripId` de los sockets).
  String? get _tripId {
    final id = widget.trip['_id'] ?? widget.trip['id'] ?? widget.trip['viajeId'] ?? widget.trip['tripId'];
    final s = id?.toString();
    return (s == null || s.isEmpty) ? null : s;
  }

  @override
  void initState() {
    super.initState();
    _cargarRuta();
  }

  Future<void> _cargarRuta() async {
    final id = _tripId;
    if (id == null) return;
    final ruta = await RutaViaje.obtener(id);
    if (!mounted || ruta == null || ruta.fase != 'recogida') return;
    final coords = ruta.coords;
    if (coords == null || coords.length < 2) return;
    setState(() {
      _ruta = coords;
      _rutaAproximada = ruta.aproximada;
    });
  }

  /// "Voy en camino a recoger": POST /confirm-arrival (aceptado →
  /// conductor_en_camino) y se abre la vista del viaje ya en ese estado. Si
  /// el backend lo rechaza se muestra el motivo y se abre igual la vista del
  /// viaje (ella sincroniza el estado real y tiene su propio botón).
  Future<void> _irARecoger() async {
    if (_starting) return;
    final tripId = _tripId;
    if (tripId == null) {
      _snack('Error: ID del viaje no disponible');
      return;
    }
    setState(() => _starting = true);
    var estado = TripStatus.aceptado;
    try {
      await DriverLocationService.instance.conUbicacionFresca(() => ApiClient.instance.confirmArrival(tripId));
      estado = TripStatus.enCamino;
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack('Error: ${e.toString().replaceFirst("Exception: ", "")}');
    }
    if (!mounted) return;
    setState(() => _starting = false);

    final capturedTrip = Map<String, dynamic>.from(widget.trip);
    capturedTrip['id'] = tripId;
    // Flujo del backend: conductor_en_camino -> conductor_llegada -> en_curso.
    capturedTrip['estado'] = estado;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (ctx) => TripInProgressScreen(trip: Trip.fromJson(capturedTrip)),
      ),
    );
  }

  Future<void> _cancelarViaje() async {
    final tripId = _tripId;
    if (tripId == null) {
      _snack('Error: ID del viaje no disponible');
      return;
    }
    setState(() => _cancelling = true);
    try {
      await ApiClient.instance.cancelTrip(tripId, motivo: 'Cancelado por el conductor');
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: ${e.toString().replaceFirst("Exception: ", "")}'),
        ));
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  void _mostrarTelefono() {
    final cliente = widget.trip['cliente'] as Map<String, dynamic>?;
    final telefono = cliente?['telefono'] as String?;
    if (telefono == null || telefono.isEmpty) {
      _snack('No hay número de teléfono disponible');
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(widget.cliente.nombre),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.phone, size: 48, color: Color(0xFF2563EB)),
          const SizedBox(height: 12),
          Text(telefono, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  void _abrirChat() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TripChatScreen(trip: widget.trip)),
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return ViajeAceptadoScreen(
      nombreCliente: widget.cliente.nombre,
      ratingCliente: widget.cliente.rating,
      avatarUrl: widget.cliente.avatarUrl,
      origen: widget.origen,
      destino: widget.destino,
      precioAcordado: widget.montoOferta,
      isStarting: _starting,
      isCancelling: _cancelling,
      onLlamar: _mostrarTelefono,
      onMensaje: _abrirChat,
      onIniciarViaje: _irARecoger,
      onCancelarViaje: _cancelarViaje,
      origenPos: MapaViaje.puntoDe(widget.trip['origen']),
      destinoPos: MapaViaje.puntoDe(widget.trip['destino']),
      vehiculoPos: MapaViaje.punto(DriverLocationService.instance.lastLat, DriverLocationService.instance.lastLng),
      ruta: _ruta,
      rutaAproximada: _rutaAproximada,
    );
  }
}
