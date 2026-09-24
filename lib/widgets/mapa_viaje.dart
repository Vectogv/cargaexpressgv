import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/map_config.dart';

/// Mapa real (Mapbox u OSM de respaldo) para las pantallas de detalle del
/// viaje: marca origen, destino y el vehículo cuando se conocen, y encuadra
/// la cámara para que se vean todos. Sin ningún punto muestra un fondo neutro
/// en lugar de un mapa inventado.
class MapaViaje extends StatefulWidget {
  final LatLng? origen;
  final LatLng? destino;
  final LatLng? vehiculo;

  const MapaViaje({super.key, this.origen, this.destino, this.vehiculo});

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
  static const _interaction = InteractionOptions(flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag);

  late final List<LatLng> _iniciales = _puntos();
  late final MapOptions _options = _iniciales.length > 1
      ? MapOptions(
          initialCameraFit: CameraFit.coordinates(
            coordinates: _iniciales,
            padding: const EdgeInsets.all(48),
            maxZoom: 16,
          ),
          interactionOptions: _interaction,
        )
      : MapOptions(
          initialCenter: _iniciales.isEmpty ? const LatLng(0, 0) : _iniciales.first,
          initialZoom: 15,
          interactionOptions: _interaction,
        );

  @override
  void initState() {
    super.initState();
    // El token de Mapbox puede no estar aún: al llegar se redibujan las teselas.
    final antes = MapConfig.tileUrl;
    MapConfig.ensureLoaded().then((_) {
      if (mounted && MapConfig.tileUrl != antes) setState(() {});
    });
  }

  List<LatLng> _puntos() => [
        if (widget.origen != null) widget.origen!,
        if (widget.destino != null) widget.destino!,
        if (widget.vehiculo != null) widget.vehiculo!,
      ];

  @override
  Widget build(BuildContext context) {
    if (_iniciales.isEmpty) {
      return const ColoredBox(
        color: Color(0xFFE8EDF2),
        child: Center(child: Icon(Icons.map_outlined, size: 40, color: Color(0xFF9CA3AF))),
      );
    }
    final url = MapConfig.tileUrl;
    return FlutterMap(
      options: _options,
      children: [
        TileLayer(key: ValueKey(url), urlTemplate: url, userAgentPackageName: 'com.cargaexpress.app'),
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
