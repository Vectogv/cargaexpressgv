import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/api_client.dart';
import '../../services/map_config.dart';
import '../../services/notification_service.dart';
import '../../services/socket_service_client.dart';
import 'trip_chat_screen.dart';

class TripInProgressScreen extends StatefulWidget {
  final Map<String, dynamic>? trip;
  const TripInProgressScreen({super.key, this.trip});

  @override
  State<TripInProgressScreen> createState() => _TripInProgressScreenState();
}

class _TripInProgressScreenState extends State<TripInProgressScreen> {
  Map<String, dynamic>? _trip;
  bool _loading = true;
  bool _actionLoading = false;
  Timer? _locationTimer;
  StreamSubscription<Map<String, dynamic>>? _gpsSubscription;
  double? _currentLat;
  double? _currentLng;
  int _elapsedSeconds = 0;
  Timer? _elapsedTimer;
  StreamSubscription<Map<String, dynamic>>? _finalizeResponseSub;

  static const Color _primaryDark = Color(0xFF1A3C6E);
  static const Color _primaryBlue = Color(0xFF1565C0);
  static const Color _accentGreen = Color(0xFF4CAF50);
  static const Color _textDark = Color(0xFF1A1A2E);
  static const Color _textGrey = Color(0xFF757575);
  static const Color _bgLight = Color(0xFFF5F7FA);
  static const Color _white = Colors.white;
  static const Color _activeStep = Color(0xFF1565C0);

  @override
  void initState() {
    super.initState();
    _gpsSubscription = NotificationService.instance.onNotification.listen(_onSocketEvent);
    _finalizeResponseSub = SocketServiceClient.instance.onFinalizeResponse.listen(_onFinalizeResponse);
    _initLocation();
    if (widget.trip != null) {
      _trip = widget.trip;
      _loading = false;
      _startGpsTimer();
    } else {
      _fetchActiveTrip();
    }
  }

  @override
  void dispose() {
    _stopGpsTimer();
    _elapsedTimer?.cancel();
    _gpsSubscription?.cancel();
    _finalizeResponseSub?.cancel();
    super.dispose();
  }

  Future<void> _initLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      if (mounted) setState(() { _currentLat = pos.latitude; _currentLng = pos.longitude; });
    } catch (e) {
      debugPrint('trip_in_progress._initLocation error: $e');
    }
  }

  void _onSocketEvent(Map<String, dynamic> event) {
    final tipo = event['__event'] as String?;
    if (tipo == 'driver:stop_gps') {
      _stopGpsTimer();
    } else if (tipo == 'trip:cancelled') {
      if (mounted) {
        _snack('El viaje ha sido cancelado');
        _stopGpsTimer();
        Navigator.pop(context);
      }
    }
  }

  void _onFinalizeResponse(Map<String, dynamic> data) {
    final accepted = data['accepted'] == true;
    if (mounted) {
      Navigator.pop(context);
      if (accepted) {
        _finalizeTrip();
      } else {
        _snack('El cliente rechaz\u00f3 la confirmaci\u00f3n. Se notificar\u00e1 al administrador.');
        ApiClient.instance.disputeTrip(
          _trip!['id'],
          motivo: 'Cliente rechaz\u00f3 confirmaci\u00f3n de entrega',
        );
      }
    }
  }

  Future<void> _requestFinalization() async {
    if (_trip == null) return;
    setState(() => _actionLoading = true);

    SocketServiceClient.instance.emit('trip:finalize_request', {
      'tripId': _trip!['id'],
      'trip': _trip,
    });

    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Esperando confirmaci\u00f3n'),
        content: const Text('Solicitando confirmaci\u00f3n al cliente...'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
    setState(() => _actionLoading = false);
  }

  Future<void> _fetchActiveTrip() async {
    try {
      final trip = await ApiClient.instance.getActiveTrip();
      if (mounted) setState(() { _trip = trip; _loading = false; });
      _startGpsTimer();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _startGpsTimer() async {
    if (_locationTimer != null) return;

    final granted = await _requestLocationPermission();
    if (!granted) return;

    _locationTimer = Timer.periodic(const Duration(seconds: 10), (_) => _sendLocation());
    _sendLocation();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
  }

  void _stopGpsTimer() {
    _locationTimer?.cancel();
    _locationTimer = null;
    _elapsedTimer?.cancel();
  }

  Future<bool> _requestLocationPermission() async {
    var status = await Permission.location.status;
    if (status.isGranted) return true;
    status = await Permission.location.request();
    if (status.isGranted) return true;
    if (!mounted) return false;
    final shouldOpen = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Permiso de ubicaci\u00f3n'),
        content: const Text('Esta funci\u00f3n requiere acceso a la ubicaci\u00f3n para enviar tu posici\u00f3n en tiempo real.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Abrir ajustes')),
        ],
      ),
    );
    if (shouldOpen == true) {
      await openAppSettings();
    }
    return false;
  }

  Future<void> _sendLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (mounted) setState(() { _currentLat = pos.latitude; _currentLng = pos.longitude; });
      await ApiClient.instance.updateLocation(pos.latitude, pos.longitude);
    } catch (e) {
      if (e.toString().contains('429') || e.toString().contains('RateLimited')) return;
    }
  }

  Future<void> _startTrip() async {
    if (_trip == null) return;
    setState(() => _actionLoading = true);
    try {
      await ApiClient.instance.startTrip(_trip!['id']);
      _trip!['estado'] = 'en_curso';
      if (mounted) setState(() {});
      _snack('Viaje iniciado');
      _startGpsTimer();
    } catch (e) {
      _snack('Error: ${e.toString().replaceFirst("Exception: ", "")}');
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _finalizeTrip() async {
    if (_trip == null) return;
    setState(() => _actionLoading = true);
    try {
      await ApiClient.instance.finalizeTrip(_trip!['id']);
      _trip!['estado'] = 'finalizado';
      if (mounted) setState(() {});
      _snack('Viaje finalizado');
      _stopGpsTimer();
    } catch (e) {
      _snack('Error: ${e.toString().replaceFirst("Exception: ", "")}');
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  String _formatElapsed() {
    final h = _elapsedSeconds ~/ 3600;
    final m = (_elapsedSeconds % 3600) ~/ 60;
    final s = _elapsedSeconds % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m ${s}s';
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  bool get _isTripActive {
    final e = _trip?['estado'] as String?;
    return e == 'aceptado' || e == 'en_curso' || e == 'completado';
  }

  bool get _isNearDestination {
    if (_currentLat == null || _currentLng == null) return false;
    final destino = _trip?['destino'] as Map<String, dynamic>?;
    if (destino == null) return false;
    final dLat = double.tryParse(destino['lat']?.toString() ?? '');
    final dLng = double.tryParse(destino['lng']?.toString() ?? '');
    if (dLat == null || dLng == null) return false;
    final dist = _haversine(_currentLat!, _currentLng!, dLat, dLng) * 1000;
    return dist <= 150;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(backgroundColor: _bgLight, body: const Center(child: CircularProgressIndicator()));
    }
    if (_trip == null) {
      return Scaffold(
        backgroundColor: _bgLight,
        appBar: AppBar(backgroundColor: _white, foregroundColor: _textDark, elevation: 0, title: const Text('Viaje en curso')),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.local_shipping, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text('No hay viaje activo', style: TextStyle(fontSize: 16, color: Colors.black45)),
          ]),
        ),
      );
    }

    final t = _trip!;
    final origen = t['origen'] as Map<String, dynamic>?;
    final destino = t['destino'] as Map<String, dynamic>?;
    final estado = t['estado'] as String? ?? '';

    return PopScope(
      canPop: !_isTripActive,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && mounted) {
          _snack('Acci\u00f3n no permitida hasta finalizar el viaje.');
        }
      },
      child: Scaffold(
        backgroundColor: _bgLight,
        body: Column(
          children: [
            _buildHeader(context, estado),
            Expanded(child: _buildMapWithContent(t, origen, destino, estado)),
            _buildBottomNav(t, estado),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String estado) {
    return Container(
      color: _white,
      padding: const EdgeInsets.only(top: 44, left: 16, right: 16, bottom: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              if (_isTripActive) {
                _snack('Acci\u00f3n no permitida hasta finalizar el viaje.');
              } else {
                Navigator.pop(context);
              }
            },
            child: Icon(Icons.arrow_back_ios_new, size: 20, color: _textDark),
          ),
          const SizedBox(width: 12),
          const Text('Viaje en curso', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _textDark)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: _accentGreen.withOpacity(0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: _accentGreen.withOpacity(0.4))),
            child: Text(estado == 'aceptado' ? 'Aceptado' : 'En curso', style: TextStyle(color: _accentGreen, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildMapWithContent(Map<String, dynamic> t, Map<String, dynamic>? origen, Map<String, dynamic>? destino, String estado) {
    final oLat = double.tryParse(origen?['lat']?.toString() ?? '') ?? 0;
    final oLng = double.tryParse(origen?['lng']?.toString() ?? '') ?? 0;
    final dLat = double.tryParse(destino?['lat']?.toString() ?? '') ?? 0;
    final dLng = double.tryParse(destino?['lng']?.toString() ?? '') ?? 0;
    final centerLat = _currentLat ?? oLat;
    final centerLng = _currentLng ?? oLng;

    final markers = <Marker>[
      Marker(point: LatLng(oLat, oLng), width: 48, height: 48, child: Container(
        decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3), boxShadow: [BoxShadow(color: Colors.green.withValues(alpha: 0.4), blurRadius: 8)]),
        child: const Icon(Icons.person, color: Colors.white, size: 26),
      )),
      Marker(point: LatLng(dLat, dLng), width: 36, height: 36, child: const Icon(Icons.location_on, color: Colors.red, size: 36)),
    ];

    if (_currentLat != null && _currentLng != null) {
      markers.add(Marker(
        point: LatLng(_currentLat!, _currentLng!),
        width: 48, height: 48,
        child: Container(
          decoration: BoxDecoration(
            color: _primaryBlue,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [BoxShadow(color: _primaryBlue.withValues(alpha: 0.4), blurRadius: 8)],
          ),
          child: const Icon(Icons.local_shipping, color: Colors.white, size: 26),
        ),
      ));
    }

    return Column(
      children: [
        Expanded(
          flex: 3,
          child: FlutterMap(
            options: MapOptions(initialCenter: LatLng(centerLat, centerLng), initialZoom: 13),
            children: [
              TileLayer(urlTemplate: MapConfig.tileUrl, userAgentPackageName: 'com.cargaexpress.app', errorImage: const AssetImage('')),
              MarkerLayer(markers: markers),
            ],
          ),
        ),
        Expanded(
          flex: 2,
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(color: _white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (_currentLat != null)
                  _buildTripInfoBar(oLat, oLng, dLat, dLng),
                const SizedBox(height: 12),
                _buildStepper(estado),
                const SizedBox(height: 12),
                _routeRow(Icons.trip_origin, 'Origen', origen?['direccion'] as String? ?? '', Colors.green),
                const SizedBox(height: 6),
                _routeRow(Icons.location_on, 'Destino', destino?['direccion'] as String? ?? '', Colors.red),
                if (estado == 'en_curso' && _isNearDestination) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: _accentGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: _accentGreen.withOpacity(0.3))),
                    child: Row(children: [
                      Icon(Icons.check_circle, size: 18, color: _accentGreen),
                      const SizedBox(width: 8),
                      const Expanded(child: Text('Has llegado al destino', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                    ]),
                  ),
                ],
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  _infoChip('Carga', t['carga'] as String? ?? 'N/A'),
                  _infoChip('Precio', '\$${(t['precioFinal'] as num? ?? t['precioEstimado'] as num?)?.toStringAsFixed(0) ?? '0'}'),
                ]),
                const SizedBox(height: 12),
                _clientSection(t['cliente'] as Map<String, dynamic>?),
                const SizedBox(height: 12),
                if (estado == 'aceptado')
                  _actionButton('Iniciar viaje', _startTrip, _primaryDark)
                else if (estado == 'en_curso' && _isNearDestination)
                  _actionButton('Finalizar viaje', _requestFinalization, _accentGreen)
                else if (estado == 'completado')
                  _actionButton('Finalizar viaje', _finalizeTrip, _primaryBlue),
              ]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTripInfoBar(double oLat, double oLng, double dLat, double dLng) {
    final distOrigen = _haversine(_currentLat!, _currentLng!, oLat, oLng);
    final distDestino = _haversine(_currentLat!, _currentLng!, dLat, dLng);
    final velocidad = 30.0;
    final minDestino = distDestino > 0 ? (distDestino / velocidad * 60).round() : 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _bgLight, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('A ${distOrigen.toStringAsFixed(1)} km del origen', style: TextStyle(fontSize: 12, color: _textGrey)),
          const SizedBox(height: 4),
          Row(children: [
            Text('Destino: ', style: TextStyle(fontSize: 12, color: _textGrey)),
            Text('$minDestino min', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _primaryDark)),
          ]),
        ]),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: _primaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.timer_outlined, size: 14, color: _primaryBlue),
            const SizedBox(width: 4),
            Text(_formatElapsed(), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: _primaryBlue)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildStepper(String estado) {
    final steps = ['Aceptado', 'En curso', 'Completado', 'Finalizado'];
    final estados = ['aceptado', 'en_curso', 'completado', 'finalizado'];
    final current = estados.indexOf(estado);
    return Row(
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          return Expanded(child: Container(height: 2, color: i ~/ 2 < current ? _activeStep : Colors.grey.shade300));
        }
        final idx = i ~/ 2;
        final active = idx <= current;
        return Container(
          width: 28, height: 28,
          decoration: BoxDecoration(color: active ? _activeStep : Colors.grey.shade300, shape: BoxShape.circle),
          child: Center(
            child: idx < current
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : Text('${idx + 1}', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        );
      }),
    );
  }

  Widget _routeRow(IconData icon, String label, String dir, Color color) {
    return Row(children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.black45)),
        Text(dir, style: const TextStyle(fontWeight: FontWeight.w500)),
      ])),
    ]);
  }

  Widget _infoChip(String label, String value) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 12, color: _textGrey)),
      const SizedBox(height: 2),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
    ]);
  }

  Widget _clientSection(Map<String, dynamic>? cliente) {
    if (cliente == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _bgLight, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        CircleAvatar(radius: 16, backgroundColor: _primaryDark, child: Text(_initials(cliente['nombre'] as String? ?? ''), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
        const SizedBox(width: 10),
        Expanded(child: Text(cliente['nombre'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w600))),
        if (cliente['telefono'] != null)
          IconButton(icon: const Icon(Icons.phone, size: 20), color: _primaryBlue, onPressed: () {}),
      ]),
    );
  }

  Widget _actionButton(String label, VoidCallback onPressed, Color color) {
    return SizedBox(
      width: double.infinity, height: 48,
      child: ElevatedButton(
        onPressed: _actionLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color, foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0,
        ),
        child: _actionLoading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      ),
    );
  }

  Widget _buildBottomNav(Map<String, dynamic> t, String estado) {
    return Container(
      padding: const EdgeInsets.only(bottom: 24, top: 8),
      decoration: const BoxDecoration(color: _white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2))]),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _navItem(Icons.chat_bubble_outline, 'Chat', () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => TripChatScreen(trip: t)));
        }),
        _navItem(Icons.phone_outlined, 'Llamar', () => _showClientPhone(t)),
        _navItem(Icons.info_outline, 'Detalle', () => _showClientDetail(t)),
        if (estado == 'aceptado')
          _navItem(Icons.cancel_outlined, 'Cancelar', () => _cancelTrip(t)),
        if (estado == 'en_curso')
          _navItem(Icons.report_problem_outlined, 'Solicitar cancelaci\u00f3n', () => _requestCancellation(t)),
      ]),
    );
  }

  Widget _navItem(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 22, color: _textGrey),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, color: _textGrey)),
      ]),
    );
  }

  void _showClientPhone(Map<String, dynamic> t) {
    final cliente = t['cliente'] as Map<String, dynamic>?;
    final nombre = cliente?['nombre'] as String? ?? 'Cliente';
    final telefono = cliente?['telefono'] as String?;
    if (telefono == null || telefono.isEmpty) {
      _snack('No hay n\u00famero de tel\u00e9fono disponible');
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Contactar a $nombre'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.phone, size: 48, color: _primaryBlue),
          const SizedBox(height: 12),
          Text(telefono, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('$nombre - Cliente', style: const TextStyle(color: _textGrey)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  void _showClientDetail(Map<String, dynamic> t) {
    final cliente = t['cliente'] as Map<String, dynamic>?;
    if (cliente == null) {
      _snack('No hay informaci\u00f3n del cliente disponible');
      return;
    }
    final nombre = cliente['nombre'] as String? ?? 'Sin nombre';
    final telefono = cliente['telefono'] as String?;
    final calificacion = cliente['calificacion'];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Informaci\u00f3n del cliente'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: _primaryDark,
              child: Text(
                _initials(nombre),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 22),
              ),
            ),
            const SizedBox(height: 12),
            Text(nombre, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: _textDark)),
            if (telefono != null && telefono.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.phone, size: 16, color: _primaryBlue),
                const SizedBox(width: 6),
                Text(telefono, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              ]),
            ],
            if (calificacion != null) ...[
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                ...List.generate(5, (i) {
                  final val = calificacion is num ? calificacion.toInt() : 0;
                  return Icon(
                    i < val ? Icons.star_rounded : Icons.star_border_rounded,
                    color: const Color(0xFFFF8F00),
                    size: 24,
                  );
                }),
                const SizedBox(width: 4),
                Text(calificacion.toString(), style: const TextStyle(fontWeight: FontWeight.w600)),
              ]),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  Future<void> _cancelTrip(Map<String, dynamic> t) async {
    final motivoCtrl = TextEditingController();
    String? motivoSeleccionado;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Cancelar viaje'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.orange.shade200)),
                child: Row(children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text('El cliente ser\u00e1 notificado. Esta acci\u00f3n ser\u00e1 revisada.', style: TextStyle(fontSize: 13, color: Colors.orange.shade900, fontWeight: FontWeight.w500))),
                ]),
              ),
              const SizedBox(height: 16),
              const Text('Motivo de cancelaci\u00f3n:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 8),
              ...['Problema con el cliente', 'Veh\u00edculo no disponible', 'Emergencia', 'Otro'].map((m) => RadioListTile<String>(
                title: Text(m, style: const TextStyle(fontSize: 14)),
                value: m,
                groupValue: motivoSeleccionado,
                onChanged: (v) => setDialogState(() => motivoSeleccionado = v),
                dense: true,
                contentPadding: EdgeInsets.zero,
              )),
              if (motivoSeleccionado != null) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: motivoCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Describe el problema (opcional)',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(12),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Volver')),
            ElevatedButton(
              onPressed: motivoSeleccionado == null ? null : () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, foregroundColor: Colors.white),
              child: const Text('Cancelar viaje'),
            ),
          ],
        ),
      ),
    );

    if (confirmado != true || motivoSeleccionado == null) return;

    try {
      final desc = motivoCtrl.text.trim();
      await ApiClient.instance.cancelTrip(t['id'], motivo: desc.isNotEmpty ? '$motivoSeleccionado: $desc' : motivoSeleccionado);
      if (mounted) {
        _snack('Viaje cancelado. Se ha notificado al cliente.');
        Navigator.pop(context);
      }
    } catch (e) {
      _snack('Error: ${e.toString().replaceFirst("Exception: ", "")}');
    }
  }

  Future<void> _requestCancellation(Map<String, dynamic> t) async {
    final motivoCtrl = TextEditingController();
    String? motivoSeleccionado;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Solicitar cancelaci\u00f3n'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.orange.shade200)),
                child: Row(children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text('El viaje est\u00e1 en curso. Se notificar\u00e1 al cliente y a soporte.', style: TextStyle(fontSize: 13, color: Colors.orange.shade900, fontWeight: FontWeight.w500))),
                ]),
              ),
              const SizedBox(height: 16),
              const Text('Motivo de la solicitud:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 8),
              ...['Problema con el cliente', 'Emergencia', 'Veh\u00edculo averiado', 'Otro'].map((m) => RadioListTile<String>(
                title: Text(m, style: const TextStyle(fontSize: 14)),
                value: m,
                groupValue: motivoSeleccionado,
                onChanged: (v) => setDialogState(() => motivoSeleccionado = v),
                dense: true,
                contentPadding: EdgeInsets.zero,
              )),
              if (motivoSeleccionado != null) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: motivoCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Explica con detalle lo que est\u00e1 pasando',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(12),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Volver')),
            ElevatedButton(
              onPressed: motivoSeleccionado == null ? null : () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700, foregroundColor: Colors.white),
              child: const Text('Enviar solicitud'),
            ),
          ],
        ),
      ),
    );

    if (confirmado != true || motivoSeleccionado == null) return;

    try {
      final desc = motivoCtrl.text.trim();
      final motivo = desc.isNotEmpty ? '$motivoSeleccionado: $desc' : motivoSeleccionado;
      await ApiClient.instance.requestCancellation(t['id'], motivo: motivo);
      if (mounted) {
        _snack('Solicitud de cancelaci\u00f3n enviada. Se notificar\u00e1 al cliente y a soporte.');
        Navigator.pop(context);
      }
    } catch (e) {
      _snack('Error: ${e.toString().replaceFirst("Exception: ", "")}');
    }
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) + cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * asin(sqrt(a));
    return R * c;
  }

  double _toRad(double deg) => deg * pi / 180.0;

  String _initials(String? name) {
    if (name == null || name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name[0].toUpperCase();
  }
}
