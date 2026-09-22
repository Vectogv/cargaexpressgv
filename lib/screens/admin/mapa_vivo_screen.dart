import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../services/api/http_client.dart';
import '../../services/map_config.dart';
import '../../services/logger_service.dart';
import 'admin_common.dart';

/// Mapa en vivo de conductores.
///
/// GET /api/admin/trips no trae coordenadas: la posición sale de
/// GET /api/admin/drivers (`ultimaUbicacion {lat,lng}`) y se cruza con los
/// viajes activos (`conductorId`) para mostrar estado y destino.
class MapaVivoScreen extends StatefulWidget {
  const MapaVivoScreen({super.key});

  @override
  State<MapaVivoScreen> createState() => _MapaVivoScreenState();
}

class _MapaVivoScreenState extends State<MapaVivoScreen> with VisiblePolling {
  static const _activeStates = {'aceptado', 'en_curso', 'esperando_confirmacion', 'pendiente'};

  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  bool _movedToFirst = false;

  /// Marcadores precalculados en cada carga (no en cada build).
  List<Marker> _markers = const [];
  LatLng? _firstPoint;

  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _fetchTrips();
    // Refresco cada 30 s solo mientras la pantalla está visible.
    startPolling(const Duration(seconds: 30), _fetchTrips);
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  static double? _toDouble(dynamic v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}');

  Future<void> _fetchTrips() async {
    if (!mounted || _refreshing) return;
    _refreshing = true;
    try {
      final results = await Future.wait([
        HttpClient.getList('/api/admin/drivers?limit=100', auth: true),
        HttpClient.getList('/api/admin/trips?limit=100', auth: true),
      ]);
      if (!mounted) return;
      final drivers = adminMapList(results[0]);
      final trips = adminMapList(results[1]);

      final tripByDriver = <String, Map<String, dynamic>>{};
      for (final t in trips) {
        final cid = t['conductorId']?.toString();
        if (cid != null && _activeStates.contains(t['estado']) && !tripByDriver.containsKey(cid)) {
          tripByDriver[cid] = t;
        }
      }

      final markers = <Marker>[];
      LatLng? first;
      for (final d in drivers) {
        final ubic = d['ultimaUbicacion'];
        if (ubic is! Map) continue;
        final lat = _toDouble(ubic['lat']);
        final lng = _toDouble(ubic['lng']);
        if (lat == null || lng == null || lat.abs() > 90 || lng.abs() > 180) continue;
        final trip = tripByDriver[d['id']?.toString()];
        // Solo conductores en línea o con un viaje activo.
        if (d['online'] != true && trip == null) continue;
        final usuario = d['usuario'] is Map ? d['usuario'] as Map : const {};
        final name = '${usuario['nombre'] ?? ''} ${usuario['apellido'] ?? ''}'.trim();
        final point = LatLng(lat, lng);
        first ??= point;
        markers.add(Marker(
          point: point,
          width: 200,
          height: 100,
          child: _TripMarker(
            name: name.isNotEmpty ? '$name · ${d['placa'] ?? ''}' : 'Conductor ${d['placa'] ?? ''}',
            status: trip?['estado']?.toString().replaceAll('_', ' ') ?? 'disponible',
            destination: trip?['destinoDireccion']?.toString() ?? '',
          ),
        ));
      }

      setState(() {
        _markers = markers;
        _firstPoint = first;
        _loading = false;
        _error = null;
      });
      if (!_movedToFirst) _moveToFirstTrip();
    } catch (e, s) {
      LoggerService.instance.error('Error fetching live map', e, s);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = adminErrorText(e);
      });
    } finally {
      _refreshing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F7),
      appBar: AppBar(
        title: const Text('Mapa en Vivo'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _fetchTrips,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _markers.isEmpty
              ? _buildMapError()
              : Stack(
                  children: [
                    _buildMap(),
                    if (_markers.isEmpty)
                      const Positioned(
                        left: 16,
                        right: 16,
                        top: 12,
                        child: Card(
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: Text('No hay conductores en línea con ubicación reciente.'),
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _firstPoint ?? const LatLng(3.4516, -76.5320),
        initialZoom: 12,
        onMapReady: _moveToFirstTrip,
      ),
      children: [
        TileLayer(
          urlTemplate: MapConfig.tileUrl,
          userAgentPackageName: 'com.cargaexpress.app',
        ),
        if (_markers.isNotEmpty) MarkerLayer(markers: _markers),
      ],
    );
  }

  void _moveToFirstTrip() {
    final first = _firstPoint;
    if (first == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _mapController.move(first, 12);
        _movedToFirst = true;
      } catch (e) {
        // El mapa aún no está listo: onMapReady volverá a intentarlo.
        LoggerService.instance.info('Mapa no listo para mover: $e');
      }
    });
  }

  Widget _buildMapError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'No se pudo cargar el mapa',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Verifica tu conexión a internet y vuelve a intentarlo.',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fetchTrips,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripMarker extends StatelessWidget {
  final String name;
  final String status;
  final String destination;

  const _TripMarker({
    required this.name,
    required this.status,
    required this.destination,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          constraints: const BoxConstraints(
            maxWidth: 190,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 5,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: 0.15,
                ),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),

              if (status.isNotEmpty)
                Text(
                  status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.black87.withValues(
                      alpha: 0.6,
                    ),
                  ),
                ),

              if (destination.isNotEmpty)
                Text(
                  destination,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.black87.withValues(
                      alpha: 0.6,
                    ),
                  ),
                ),
            ],
          ),
        ),

        const Icon(
          Icons.location_on,
          color: Color(0xFFE53935),
          size: 28,
        ),
      ],
    );
  }
}