import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import '../services/trip_service.dart';
import '../services/api_client.dart';
import '../services/dispute_service.dart';
import '../models/oferta.dart';

class ClientHomeScreen extends StatefulWidget {
  const ClientHomeScreen({super.key});

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _FavoriteRoute {
  final String nombre;
  final String origen;
  final String destino;

  _FavoriteRoute({required this.nombre, required this.origen, required this.destino});

  Map<String, dynamic> toJson() => {'nombre': nombre, 'origen': origen, 'destino': destino};

  factory _FavoriteRoute.fromJson(Map<String, dynamic> json) => _FavoriteRoute(
        nombre: json['nombre'] ?? '',
        origen: json['origen'] ?? '',
        destino: json['destino'] ?? '',
      );
}

class _ClientHomeScreenState extends State<ClientHomeScreen> {
  final _origenCtrl = TextEditingController();
  final _destinoCtrl = TextEditingController();
  final _precioCtrl = TextEditingController();
  bool _solicitando = false;
  bool _matched = false;
  String? _tripId;
  String? _userId;
  List<Oferta> _ofertas = [];
  io.Socket? _socket;
  List<_FavoriteRoute> _favorites = [];

  String? _estadoCuenta;
  double _deudaMonto = 0;
  String? _nequiNumero;
  String? _nequiTitular;
  int _diasRestantes = 0;
  String? _disputeTripId;
  bool _tieneDeudaActiva = false;

  static const _centerPos = LatLng(3.4516, -76.5320); // Cali
  static const _coverageZones = [
    LatLng(3.4516, -76.5320), // Cali
    LatLng(2.4448, -76.6147), // Popayán
    LatLng(1.2136, -77.2811), // Pasto
  ];
  static const _coverageRadiusKm = 50.0;

  @override
  void initState() {
    super.initState();
    _loadUserId();
    _loadFavorites();
    _checkEstadoCuenta();
  }

  Future<void> _checkEstadoCuenta() async {
    try {
      final res = await ApiClient().get('/users/account-status');
      if (!mounted) return;
      setState(() {
        _estadoCuenta = res['estado_cuenta'] ?? 'normal';
        _deudaMonto = (res['deudaMonto'] ?? 0).toDouble();
        _nequiNumero = res['nequiNumero'];
        _nequiTitular = res['nequiTitular'];
        _diasRestantes = res['diasRestantes'] ?? 0;
        _disputeTripId = res['disputeTripId'];
        _tieneDeudaActiva = res['tieneDeudaActiva'] ?? false;
      });
    } catch (_) {
      if (mounted) setState(() => _estadoCuenta = 'normal');
    }
  }

  double _distanceTo(LatLng a, LatLng b) {
    return const Distance().as(LengthUnit.Meter, a, b) / 1000;
  }

  bool _isInCoverageZone(LatLng point) {
    for (final zone in _coverageZones) {
      if (_distanceTo(point, zone) <= _coverageRadiusKm) return true;
    }
    return false;
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('userId');
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('favoriteRoutes');
    if (data != null) {
      final list = jsonDecode(data) as List<dynamic>;
      setState(() {
        _favorites = list.map((e) => _FavoriteRoute.fromJson(e as Map<String, dynamic>)).toList();
      });
    }
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(_favorites.map((f) => f.toJson()).toList());
    await prefs.setString('favoriteRoutes', data);
  }

  void _saveCurrentAsFavorite() {
    final origen = _origenCtrl.text;
    final destino = _destinoCtrl.text;
    if (origen.isEmpty || destino.isEmpty) return;

    final nombreCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Guardar ruta favorita', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: nombreCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Nombre (ej: Casa-Trabajo)',
            hintStyle: TextStyle(color: Colors.white38),
            filled: true, fillColor: Colors.white.withValues(alpha: 0.06),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              if (nombreCtrl.text.isEmpty) return;
              setState(() {
                _favorites.insert(0, _FavoriteRoute(
                  nombre: nombreCtrl.text,
                  origen: origen,
                  destino: destino,
                ));
              });
              _saveFavorites();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Ruta guardada como favorita'), backgroundColor: Colors.green),
              );
            },
            child: const Text('Guardar', style: TextStyle(color: Color(0xFF1A8CFF))),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _origenCtrl.dispose();
    _destinoCtrl.dispose();
    _precioCtrl.dispose();
    _socket?.disconnect();
    _socket?.dispose();
    super.dispose();
  }

  String get _socketServerUrl {
    final base = ApiClient().baseUrl;
    if (base.endsWith('/api')) {
      return base.substring(0, base.length - 4);
    }
    return base;
  }

  void _conectarSocket() {
    if (_userId == null) return;

    _socket = io.io(_socketServerUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    _socket!.connect();

    _socket!.onConnect((_) {
      _socket!.emit('join:client', _userId);
    });

    _socket!.on('offer:new', (data) {
      if (!mounted) return;
      setState(() {
        _ofertas.add(Oferta.fromJson(data as Map<String, dynamic>));
      });
    });

    _socket!.on('offer:accepted', (data) {
      if (!mounted) return;
      setState(() => _matched = true);
    });
  }

  Future<void> _solicitarViaje() async {
    final precio = double.tryParse(_precioCtrl.text);
    if (precio == null || precio <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ingresa un precio válido'), backgroundColor: Colors.red),
      );
      return;
    }

    if (!_isInCoverageZone(_centerPos)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Servicio no disponible en esta zona. Operamos en Cali, Popayán y Pasto.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() => _solicitando = true);

    try {
      final trip = await TripService().requestTrip(
        origenDireccion: _origenCtrl.text,
        origenLat: _centerPos.latitude,
        origenLng: _centerPos.longitude,
        destinoDireccion: _destinoCtrl.text,
        destinoLat: _centerPos.latitude + 0.01,
        destinoLng: _centerPos.longitude + 0.01,
        precioCliente: precio,
      );

      _tripId = trip.id;
      _conectarSocket();
    } catch (e) {
      if (!mounted) return;
      setState(() => _solicitando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al solicitar: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _aceptarOferta(Oferta oferta) async {
    if (_tripId == null) return;

    try {
      await TripService().acceptOffer(_tripId!, oferta.id);
      setState(() => _matched = true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al aceptar: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _cancelar() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    setState(() {
      _solicitando = false;
      _matched = false;
      _tripId = null;
      _ofertas = [];
    });
  }

  Future<void> _showEmergencyDialog() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Color(0xFF1A1A1A),
        title: Row(
          children: [
            Icon(Icons.emergency_share, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Emergencia', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          '¿Confirmar emergencia? Se alertará al equipo de soporte',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Confirmar', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _triggerEmergency();
    }
  }

  Future<void> _triggerEmergency() async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            SizedBox(width: 16),
            Text('Obteniendo ubicación...'),
          ],
        ),
        backgroundColor: Colors.redAccent,
      ),
    );

    try {
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      
      final api = ApiClient();
      await api.post('/emergency', body: {
        'lat': pos.latitude,
        'lng': pos.longitude,
        'timestamp': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Alerta enviada. El equipo fue notificado.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al enviar alerta: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_estadoCuenta == 'suspension_por_pago') {
      return _buildPaymentBlockScreen();
    } else if (_estadoCuenta == 'esperando_confirmacion') {
      return _buildPendingProofScreen();
    } else if (_estadoCuenta == 'baneada') {
      return _buildBannedScreen();
    }

    return Scaffold(
      body: Stack(
        children: [
          _buildMap(),
          _buildTopBar(),
          _buildDisputeBanner(),
          _buildBottomSheet(),
          if (_matched)
            Positioned(
              bottom: 340,
              right: 16,
              child: FloatingActionButton(
                onPressed: _showEmergencyDialog,
                backgroundColor: Colors.redAccent,
                child: Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDisputeBanner() {
    if (_disputeTripId == null) return const SizedBox.shrink();
    return Positioned(
      top: MediaQuery.of(context).padding.top + 80,
      left: 16, right: 16,
      child: GestureDetector(
        onTap: _showAppealScreen,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.redAccent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Tienes un reporte pendiente. Tienes 48 horas para apelar.',
                  style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.redAccent, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showAppealScreen() {
    final appealCtrl = TextEditingController();
    File? soporteFile;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4,
                      decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4)))),
                  SizedBox(height: 20),
                  Row(children: [
                    Icon(Icons.description, color: Color(0xFF1A8CFF), size: 22),
                    SizedBox(width: 10),
                    Text('Apelar reporte',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  ]),
                  SizedBox(height: 12),
                  Text('Presenta tu versión de los hechos y adjunta evidencia.',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
                  SizedBox(height: 16),
                  TextField(
                    controller: appealCtrl,
                    maxLines: 4,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Tu versión de los hechos...',
                      hintStyle: TextStyle(color: Colors.white38),
                      filled: true, fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  GestureDetector(
                    onTap: () async {
                      final picker = ImagePicker();
                      final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1024);
                      if (file != null) {
                        setModalState(() => soporteFile = File(file.path));
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Color(0xFF1A8CFF).withValues(alpha: 0.3)),
                      ),
                      child: Row(children: [
                        Icon(soporteFile != null ? Icons.check_circle : Icons.cloud_upload_outlined,
                            color: soporteFile != null ? Colors.greenAccent : Color(0xFF1A8CFF), size: 20),
                        SizedBox(width: 10),
                        Text(soporteFile != null ? 'Soporte adjunto' : 'Subir soporte (opcional)',
                            style: TextStyle(
                                color: soporteFile != null ? Colors.greenAccent : Colors.white, fontSize: 14)),
                      ]),
                    ),
                  ),
                  SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity, height: 52,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (appealCtrl.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Describe tu versión de los hechos'), backgroundColor: Colors.red),
                          );
                          return;
                        }
                        Navigator.pop(ctx);
                        try {
                          await DisputeService().appealDispute(
                            _disputeTripId!,
                            version: appealCtrl.text,
                            soporte: soporteFile,
                          );
                          if (!mounted) return;
                          setState(() => _disputeTripId = null);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Tu apelación fue enviada.'), backgroundColor: Colors.green),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF1A8CFF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text('Enviar apelación', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPaymentBlockScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_outline, color: Colors.redAccent, size: 48),
              ),
              const SizedBox(height: 24),
              const Text('Cuenta suspendida',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                'Tienes un saldo pendiente. Realiza el pago para continuar usando el servicio.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
              ),
              const SizedBox(height: 32),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Column(
                  children: [
                    Text('MONTO DE LA DEUDA',
                        style: TextStyle(color: Colors.redAccent.withValues(alpha: 0.6), fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text('\$${_deudaMonto.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.redAccent, fontSize: 36, fontWeight: FontWeight.bold)),
                    if (_diasRestantes > 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${_diasRestantes} día(s) restantes',
                        style: TextStyle(
                          color: _diasRestantes < 3 ? Colors.redAccent : Colors.white.withValues(alpha: 0.5),
                          fontSize: 14,
                          fontWeight: _diasRestantes < 3 ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (_nequiNumero != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A8CFF).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF1A8CFF).withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    children: [
                      Text('Realiza el pago a este Nequi:',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
                      const SizedBox(height: 8),
                      Text(_nequiNumero!,
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      if (_nequiTitular != null) ...[
                        const SizedBox(height: 4),
                        Text(_nequiTitular!,
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton.icon(
                  onPressed: _uploadPaymentProof,
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: const Text('Subir comprobante de pago'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A8CFF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _uploadPaymentProof() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1024);
    if (file == null) return;

    try {
      await ApiClient().upload('/payment/proof', file.path, 'comprobante');
      if (!mounted) return;
      setState(() => _estadoCuenta = 'esperando_confirmacion');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tu comprobante está siendo revisado.'), backgroundColor: Color(0xFF1A8CFF)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildPendingProofScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.hourglass_empty_rounded, color: Colors.amber, size: 48),
                ),
                const SizedBox(height: 24),
                const Text('Comprobante en revisión',
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text(
                  'Tu comprobante de pago está siendo revisado. Te notificaremos cuando sea aprobado.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBannedScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.block, color: Colors.redAccent, size: 48),
                ),
                const SizedBox(height: 24),
                const Text('Cuenta suspendida',
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text(
                  'Tu cuenta ha sido suspendida. Contacta a soporte para más información.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMap() {
    return FlutterMap(
      options: MapOptions(initialCenter: _centerPos, initialZoom: 15),
      children: [
        TileLayer(
          urlTemplate:
              'https://tiles.stadiamaps.com/tiles/alidade_smooth_dark/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.cargaexpress.app',
        ),
        if (_matched)
          MarkerLayer(
            markers: [
              Marker(
                point: _centerPos,
                width: 100,
                height: 100,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('¡En camino!',
                          style: TextStyle(color: Colors.white, fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                    SizedBox(height: 4),
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [BoxShadow(
                            color: Colors.green.withValues(alpha: 0.5),
                            blurRadius: 10)],
                      ),
                      child: Icon(Icons.navigation, color: Colors.white, size: 20),
                    ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: Container(
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.menu_rounded, color: Colors.white, size: 22),
              ),
              Spacer(),
              Text('CargaExpress',
                  style: TextStyle(color: Colors.white, fontSize: 18,
                      fontWeight: FontWeight.bold)),
              Spacer(),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.person_outline, color: Colors.white, size: 22),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSheet() {
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: Color(0xFF0D0D0D),
          borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28), topRight: Radius.circular(28)),
          boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 30, offset: Offset(0, -10))],
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4))),
              SizedBox(height: 20),
              if (!_solicitando && !_matched)
                _buildForm()
              else if (_solicitando && !_matched && _ofertas.isEmpty)
                _buildBuscando()
              else if (_solicitando && !_matched && _ofertas.isNotEmpty)
                _buildOffersList()
              else
                _buildMatched(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('¿A dónde vas?',
                style: TextStyle(color: Colors.white, fontSize: 22,
                    fontWeight: FontWeight.bold)),
            Spacer(),
            if (_origenCtrl.text.isNotEmpty && _destinoCtrl.text.isNotEmpty)
              GestureDetector(
                onTap: _saveCurrentAsFavorite,
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.star_border_rounded, color: Colors.amber, size: 20),
                ),
              ),
          ],
        ),
        if (_favorites.isNotEmpty) ...[
          SizedBox(height: 12),
          _buildFavoritesList(),
        ],
        SizedBox(height: 16),
        _buildDireccionField(
          controller: _origenCtrl,
          hint: 'Tu ubicación',
          icon: Icons.circle,
          iconColor: Color(0xFF1A8CFF),
          readOnly: true,
          value: 'Av. Principal, Los Palos Grandes',
        ),
        SizedBox(height: 12),
        _buildDireccionField(
          controller: _destinoCtrl,
          hint: '¿A dónde va la carga?',
          icon: Icons.square,
          iconColor: Colors.white.withValues(alpha: 0.4),
        ),
        SizedBox(height: 12),
        _buildPrecioField(),
        SizedBox(height: 24),
        if (_tieneDeudaActiva) ...[
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 16, color: Colors.redAccent),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tienes una deuda activa. Realiza el pago para solicitar nuevos viajes.',
                    style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
        ],
        SizedBox(
          width: double.infinity, height: 54,
          child: ElevatedButton(
            onPressed: _destinoCtrl.text.isNotEmpty && !_tieneDeudaActiva ? _solicitarViaje : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF1A8CFF),
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.white.withValues(alpha: 0.08),
              disabledForegroundColor: Colors.white.withValues(alpha: 0.2),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 4,
              shadowColor: Color(0xFF1A8CFF).withValues(alpha: 0.4),
            ),
            child: Text('Solicitar envío',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _buildFavoritesList() {
    final visible = _favorites.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.star, size: 14, color: Colors.amber),
            SizedBox(width: 6),
            Text('Rutas favoritas',
                style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
        SizedBox(height: 8),
        ...visible.map((fav) => GestureDetector(
          onTap: () {
            _origenCtrl.text = fav.origen;
            _destinoCtrl.text = fav.destino;
          },
          child: Container(
            margin: EdgeInsets.only(bottom: 6),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                Icon(Icons.star, size: 14, color: Colors.amber.withValues(alpha: 0.6)),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fav.nombre,
                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                      Text('${fav.origen} → ${fav.destino}',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
        )),
      ],
    );
  }

  Widget _buildPrecioField() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Icon(Icons.attach_money, size: 20, color: Colors.greenAccent),
          SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _precioCtrl,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText: '¿Cuánto pagas? (ej: 35.00)',
                hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3), fontSize: 15),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDireccionField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required Color iconColor,
    bool readOnly = false,
    String? value,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              readOnly: readOnly,
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText: value ?? hint,
                hintStyle: TextStyle(
                    color: value != null
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.3),
                    fontSize: 15),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuscando() {
    return Column(
      children: [
        SizedBox(height: 8),
        SizedBox(
          width: 72, height: 72,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation(Color(0xFF1A8CFF)),
          ),
        ),
        SizedBox(height: 16),
        Text('Buscando conductor...',
            style: TextStyle(color: Colors.white, fontSize: 18,
                fontWeight: FontWeight.w600)),
        Text('Estamos buscando un conductor disponible',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.4),
                fontSize: 13)),
        SizedBox(height: 24),
        SizedBox(
          width: double.infinity, height: 52,
          child: ElevatedButton(
            onPressed: _cancelar,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
              ),
              elevation: 0,
            ),
            child: Text('Cancelar',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _buildOffersList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: 4),
        Text('Ofertas recibidas (${_ofertas.length})',
            style: TextStyle(color: Colors.white, fontSize: 18,
                fontWeight: FontWeight.bold)),
        SizedBox(height: 12),
        SizedBox(
          height: 320,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: _ofertas.length,
            separatorBuilder: (_, _) => SizedBox(height: 10),
            itemBuilder: (_, i) => _buildOfferCard(_ofertas[i]),
          ),
        ),
        SizedBox(height: 12),
        SizedBox(
          width: double.infinity, height: 52,
          child: ElevatedButton(
            onPressed: _cancelar,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
              ),
              elevation: 0,
            ),
            child: Text('Cancelar viaje',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _buildOfferCard(Oferta oferta) {
    final nombre = oferta.conductor['nombre'] as String? ?? 'Conductor';
    final calificacion = (oferta.conductor['calificacion'] as num?)?.toDouble() ?? 0;
    final placa = oferta.conductor['placa'] as String? ?? '';
    final tipoVehiculo = oferta.conductor['tipoVehiculo'] as String? ?? '';
    final foto = oferta.conductor['foto'] as String?;

    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: Color(0xFF1A8CFF).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: Color(0xFF1A8CFF).withValues(alpha: 0.3), width: 2),
            ),
            child: foto != null && foto.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(foto, fit: BoxFit.cover),
                  )
                : Center(
                    child: Text(
                      nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
                      style: TextStyle(color: Colors.white, fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nombre,
                    style: TextStyle(color: Colors.white, fontSize: 15,
                        fontWeight: FontWeight.bold)),
                SizedBox(height: 2),
                Row(
                  children: [
                    Text('$calificacion ⭐',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 12)),
                    if (tipoVehiculo.isNotEmpty) ...[
                      Text(' · ',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.3),
                              fontSize: 12)),
                      Text(tipoVehiculo,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 12)),
                    ],
                    if (placa.isNotEmpty) ...[
                      Text(' · ',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.3),
                              fontSize: 12)),
                      Text(placa,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 12)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('\$${oferta.monto.toStringAsFixed(2)}',
                  style: TextStyle(color: Colors.greenAccent, fontSize: 16,
                      fontWeight: FontWeight.bold)),
              SizedBox(height: 6),
              SizedBox(
                height: 32,
                child: ElevatedButton(
                  onPressed: () => _aceptarOferta(oferta),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF1A8CFF),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: Text('Aceptar',
                      style: TextStyle(fontSize: 13,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMatched() {
    final ofertaAceptada = _ofertas.isNotEmpty ? _ofertas.first : null;
    final nombre = ofertaAceptada?.conductor['nombre'] as String? ?? 'Conductor';

    return Column(
      children: [
        SizedBox(height: 4),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 8, height: 8,
                  decoration: BoxDecoration(
                      color: Colors.green, shape: BoxShape.circle)),
              SizedBox(width: 6),
              Text('CONDUCTOR ASIGNADO',
                  style: TextStyle(color: Colors.green, fontSize: 11,
                      fontWeight: FontWeight.w700, letterSpacing: 1)),
            ],
          ),
        ),
        SizedBox(height: 20),
        Row(
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: Color(0xFF1A8CFF).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: Color(0xFF1A8CFF).withValues(alpha: 0.3), width: 2),
              ),
              child: Center(
                child: Text(
                  nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
                  style: TextStyle(color: Colors.white, fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
            SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nombre,
                    style: TextStyle(color: Colors.white, fontSize: 17,
                        fontWeight: FontWeight.bold)),
                Text('En camino',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 13)),
              ],
            )),
          ],
        ),
        SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _buildContactBtn(Icons.phone_rounded, 'Llamar'),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildContactBtn(Icons.chat_rounded, 'Mensaje'),
            ),
          ],
        ),
        SizedBox(height: 16),
        SizedBox(
          width: double.infinity, height: 52,
          child: ElevatedButton(
            onPressed: _cancelar,
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFE53935),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: Text('Cancelar viaje',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _buildContactBtn(IconData icon, String label) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.7), size: 18),
          SizedBox(width: 8),
          Text(label, style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7), fontSize: 14,
              fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
