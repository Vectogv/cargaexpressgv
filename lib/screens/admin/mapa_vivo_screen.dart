import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../services/api_client.dart';
import '../../services/map_config.dart';
import '../../services/logger_service.dart';

class MapaVivoScreen extends StatefulWidget {
  const MapaVivoScreen({super.key});

  @override
  State<MapaVivoScreen> createState() => _MapaVivoScreenState();
}

class _MapaVivoScreenState extends State<MapaVivoScreen> {
  bool _loading = true;
  bool _mapError = false;

  List<Map<String, dynamic>> _trips = [];

  final MapController _mapController = MapController();

  Timer? _refreshTimer;

  Map<String, String> get _authHeaders => {
        'Content-Type': 'application/json',
        if (ApiClient.instance.token != null)
          'Authorization': 'Bearer ${ApiClient.instance.token}',
      };

  @override
  void initState() {
    super.initState();

    _fetchTrips();

    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _fetchTrips(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchTrips() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
    });

    try {
      final response = await http
          .get(
            Uri.parse('${ApiClient.baseUrl}/api/admin/trips'),
            headers: _authHeaders,
          )
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (decoded is List) {
          final trips = decoded
              .whereType<Map>()
              .map(
                (item) => Map<String, dynamic>.from(item),
              )
              .toList();

          setState(() {
            _trips = trips;
            _loading = false;
            _mapError = false;
          });
        } else {
          setState(() {
            _loading = false;
            _mapError = true;
          });
        }
      } else {
        LoggerService.instance.info(
          'Trips API returned status ${response.statusCode}',
        );

        setState(() {
          _loading = false;
          _mapError = true;
        });
      }
    } catch (e, s) {
      LoggerService.instance.error(
        'Error fetching live trips',
        e,
        s,
      );

      if (!mounted) return;

      setState(() {
        _loading = false;
        _mapError = true;
      });
    }
  }

  List<Map<String, dynamic>> get _activeTrips {
    return _trips.where((trip) {
      final lat = trip['lat'];
      final lng = trip['lng'];

      return lat is num &&
          lng is num &&
          lat >= -90 &&
          lat <= 90 &&
          lng >= -180 &&
          lng <= 180;
    }).toList();
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
      body: _loading && _trips.isEmpty
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _mapError && _trips.isEmpty
              ? _buildMapError()
              : RefreshIndicator(
                  onRefresh: _fetchTrips,
                  child: _buildMap(),
                ),
    );
  }

  Widget _buildMap() {
    final activeTrips = _activeTrips;

    final markers = activeTrips.map((trip) {
      try {
        final lat = (trip['lat'] as num).toDouble();
        final lng = (trip['lng'] as num).toDouble();

        final name = trip['conductor']?.toString() ?? 'Conductor';

        final status = trip['estado']?.toString() ?? '';

        final destination = trip['destino']?.toString() ?? '';

        return Marker(
          point: LatLng(lat, lng),
          width: 200,
          height: 100,
          child: _TripMarker(
            name: name,
            status: status,
            destination: destination,
          ),
        );
      } catch (e, s) {
        LoggerService.instance.error(
          'Error building trip marker',
          e,
          s,
        );

        return null;
      }
    }).whereType<Marker>().toList();

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: const LatLng(
          4.711,
          -74.072,
        ),
        initialZoom: 12,
        onMapReady: () {
          if (!mounted) return;

          setState(() {
            _mapError = false;
          });

          _moveToFirstTrip();
        },
      ),
      children: [
        TileLayer(
          urlTemplate: MapConfig.tileUrl,
          userAgentPackageName: 'com.cargaexpress.app',
        ),

        if (markers.isNotEmpty)
          MarkerLayer(
            markers: markers,
          ),
      ],
    );
  }

  void _moveToFirstTrip() {
    final activeTrips = _activeTrips;

    if (activeTrips.isEmpty) return;

    try {
      final first = activeTrips.first;

      final lat = (first['lat'] as num).toDouble();
      final lng = (first['lng'] as num).toDouble();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        try {
          _mapController.move(
            LatLng(lat, lng),
            12,
          );
        } catch (e, s) {
          LoggerService.instance.error(
            'Error moving map to first trip',
            e,
            s,
          );
        }
      });
    } catch (e, s) {
      LoggerService.instance.error(
        'Error getting first trip location',
        e,
        s,
      );
    }
  }

  Widget _buildMapError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.map_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            const Text(
              'No se pudo cargar el mapa',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Verifica tu conexión a internet y vuelve a intentarlo.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fetchTrips,
              icon: const Icon(
                Icons.refresh,
                size: 18,
              ),
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