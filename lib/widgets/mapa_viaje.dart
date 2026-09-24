import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/map_config.dart';

/// Mapa real (Mapbox u OSM de respaldo) para las pantallas del viaje: marca
/// origen, destino y el vehículo cuando se conocen, y encuadra la cámara para
/// que se vean todos. Sin ningún punto muestra un fondo neutro en lugar de un
/// mapa inventado.
///
/// Opcionalmente dibuja la [ruta] (continua si viene del servicio de rutas,
/// punteada si es [rutaAproximada], p. ej. una línea recta de respaldo) y,
/// con [seguir], vuelve a encuadrar [encuadre] cada vez que cambia (el
/// vehículo en vivo). Un gesto del usuario se avisa con [onGestoUsuario] para
/// que la pantalla deje de seguir y ofrezca "Recentrar".
///
/// Las teselas y las opciones del mapa se crean una sola vez: en cada nueva
/// posición sólo cambian los marcadores y la línea.
class MapaViaje extends StatefulWidget {
  final LatLng? origen;
  final LatLng? destino;
  final LatLng? vehiculo;
  final List<LatLng>? ruta;
  final bool rutaAproximada;
  final List<LatLng>? encuadre;
  final bool seguir;
  final EdgeInsets padding;
  final VoidCallback? onGestoUsuario;

  const MapaViaje({
    super.key,
    this.origen,
    this.destino,
    this.vehiculo,
    this.ruta,
    this.rutaAproximada = false,
    this.encuadre,
    this.seguir = false,
    this.padding = const EdgeInsets.all(48),
    this.onGestoUsuario,
  });

  /// Lee `origen`/`destino` ({lat, lng}) del JSON del viaje.
  factory MapaViaje.desdeViaje(Map<String, dynamic> trip, {Key? key, LatLng? vehiculo}) {
    return MapaViaje(
      key: key,
      origen: puntoDe(trip['origen']),
      destino: puntoDe(trip['destino']),
      vehiculo: vehiculo,
    );
  }

  static LatLng? puntoDe(Object? json) {
    if (json is! Map) return null;
    final lat = double.tryParse('${json['lat'] ?? json['latitude']}');
    final lng = double.tryParse('${json['lng'] ?? json['longitude']}');
    if (lat == null || lng == null || (lat == 0 && lng == 0)) return null;
    return LatLng(lat, lng);
  }

  static LatLng? punto(double? lat, double? lng) {
    if (lat == null || lng == null || (lat == 0 && lng == 0)) return null;
    return LatLng(lat, lng);
  }

  @override
  State<MapaViaje> createState() => _MapaViajeState();
}

class _MapaViajeState extends State<MapaViaje> {
  static final _punteada = StrokePattern.dashed(segments: const [12, 10]);
  static const _interaction = InteractionOptions(flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag);

  final MapController _controller = MapController();
  bool _listo = false;

  late final List<LatLng> _iniciales = _puntosEncuadre();
  late final MapOptions _options = _iniciales.length > 1
      ? MapOptions(
          initialCameraFit: CameraFit.coordinates(
            coordinates: _iniciales,
            padding: widget.padding,
            maxZoom: 16,
          ),
          interactionOptions: _interaction,
          onMapReady: _alEstarListo,
          onPositionChanged: _alMoverse,
        )
      : MapOptions(
          initialCenter: _iniciales.isEmpty ? const LatLng(0, 0) : _iniciales.first,
          initialZoom: 15,
          interactionOptions: _interaction,
          onMapReady: _alEstarListo,
          onPositionChanged: _alMoverse,
        );

  late String _url = MapConfig.tileUrl;
  late TileLayer _tiles = _crearTiles();

  TileLayer _crearTiles() =>
      TileLayer(key: ValueKey(_url), urlTemplate: _url, userAgentPackageName: 'com.cargaexpress.app');

  @override
  void initState() {
    super.initState();
    // El token de Mapbox puede no estar aún: al llegar se redibujan las teselas.
    MapConfig.ensureLoaded().then((_) {
      if (!mounted || MapConfig.tileUrl == _url) return;
      setState(() {
        _url = MapConfig.tileUrl;
        _tiles = _crearTiles();
      });
    });
  }

  @override
  void didUpdateWidget(covariant MapaViaje old) {
    super.didUpdateWidget(old);
    if (!widget.seguir) return;
    final cambio = !old.seguir || !listEquals(old.encuadre ?? const [], widget.encuadre ?? const []);
    if (cambio) _encuadrar();
  }

  void _alEstarListo() {
    _listo = true;
    if (widget.seguir) _encuadrar();
  }

  void _alMoverse(MapCamera _, bool hasGesture) {
    if (hasGesture) widget.onGestoUsuario?.call();
  }

  List<LatLng> _puntosEncuadre() {
    final e = widget.encuadre;
    if (e != null && e.isNotEmpty) return e;
    return [
      if (widget.origen != null) widget.origen!,
      if (widget.destino != null) widget.destino!,
      if (widget.vehiculo != null) widget.vehiculo!,
    ];
  }

  void _encuadrar() {
    if (!_listo) return;
    final puntos = _puntosEncuadre();
    if (puntos.isEmpty) return;
    try {
      if (puntos.length == 1) {
        _controller.move(puntos.first, _controller.camera.zoom < 14 ? 15 : _controller.camera.zoom);
      } else {
        _controller.fitCamera(CameraFit.coordinates(coordinates: puntos, padding: widget.padding, maxZoom: 16));
      }
    } catch (_) {
      // El mapa aún no tiene tamaño (primer frame): el encuadre inicial ya lo cubre.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_iniciales.isEmpty) {
      return const ColoredBox(
        color: Color(0xFFE8EDF2),
        child: Center(child: Icon(Icons.map_outlined, size: 40, color: Color(0xFF9CA3AF))),
      );
    }
    final ruta = widget.ruta;
    return FlutterMap(
      mapController: _controller,
      options: _options,
      children: [
        _tiles,
        if (ruta != null && ruta.length > 1)
          PolylineLayer(polylines: [
            Polyline(
              points: ruta,
              strokeWidth: 5,
              color: const Color(0xFF2563EB),
              borderStrokeWidth: widget.rutaAproximada ? 0 : 2,
              borderColor: const Color(0xFF1E3A8A),
              pattern: widget.rutaAproximada
                  ? _punteada
                  : const StrokePattern.solid(),
            ),
          ]),
        MarkerLayer(markers: [
          if (widget.origen != null)
            Marker(
              point: widget.origen!,
              width: 34,
              height: 34,
              child: const _Punto(color: Color(0xFF16A34A), icon: Icons.trip_origin),
            ),
          if (widget.destino != null)
            Marker(
              point: widget.destino!,
              width: 36,
              height: 36,
              alignment: Alignment.topCenter,
              child: const Icon(Icons.location_on, color: Color(0xFFEF4444), size: 36),
            ),
          if (widget.vehiculo != null)
            Marker(
              point: widget.vehiculo!,
              width: 44,
              height: 44,
              child: const _Punto(color: Color(0xFF2563EB), icon: Icons.local_shipping),
            ),
        ]),
      ],
    );
  }
}

class _Punto extends StatelessWidget {
  final Color color;
  final IconData icon;
  const _Punto({required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}
