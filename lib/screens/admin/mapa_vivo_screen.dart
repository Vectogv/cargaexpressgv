import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
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
    'Authorization': 'Bearer ${ApiClient.instance.token}',
  };

  @override
  void initState() {
    super.initState();
    _fetchTrips();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _fetchTrips();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchTrips() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final res = await http.get(
        Uri.parse('${ApiClient.baseUrl}/api/admin/trips'),
        headers: _authHeaders,
      );
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        if (mounted) setState(() {
          _trips = List<Map<String, dynamic>>.from(data);
          _loading = false;
          _mapError = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _activeTrips =>
      _trips.where((t) => t['lat'] != null && t['lng'] != null).toList();

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
            icon: const Icon(Icons.refresh),
            onPressed: _fetchTrips,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _mapError
              ? _buildMapError()
              : RefreshIndicator(
                  onRefresh: _fetchTrips,
                  child: _buildMap(),
                ),
    );
  }

  Widget _buildMap() {
    final markers = _activeTrips.map((trip) {
      try {
        final lat = (trip['lat'] as num).toDouble();
        final lng = (trip['lng'] as num).toDouble();
        final name = trip['conductor'] as String? ?? '';
        final status = trip['estado'] as String? ?? '';
        final dest = trip['destino'] as String? ?? '';
        return Marker(
          point: LatLng(lat, lng),
          width: 200,
          height: 80,
          child: _TripMarker(
            name: name,
            status: status,
            destination: dest,
          ),
        );
      } catch (e, s) {
        LoggerService.instance.error('Error building trip marker', e, s);
        return null;
      }
    }).whereType<Marker>().toList();

    if (_activeTrips.isNotEmpty) {
      try {
        final first = _activeTrips.first;
        final lat = (first['lat'] as num).toDouble();
        final lng = (first['lng'] as num).toDouble();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _mapController.move(LatLng(lat, lng), 12);
          }
        });
      } catch (_) {}
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: const LatLng(4.711, -74.072),
        initialZoom: 12,
        onMapReady: () => setState(() => _mapError = false),
      ),
      children: [
        TileLayer(
          urlTemplate: MapConfig.tileUrl,
          userAgentPackageName: 'com.cargaexpress.app',
          errorImage: const AssetImage(''),
        ),
        MarkerLayer(markers: markers),
      ],
    );
  }

  Widget _buildMapError() {
    return Center(
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
            'Verifica tu conexi\u00f3n a internet',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => setState(() => _mapError = false),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Reintentar'),
          ),
        ],
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
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
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              Text(
                status,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.black87.withValues(alpha: 0.6),
                ),
              ),
              Text(
                destination,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.black87.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.location_on, color: Color(0xFFE53935), size: 28),
      ],
    );
  }
}
