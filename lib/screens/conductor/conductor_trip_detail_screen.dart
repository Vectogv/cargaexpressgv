import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../services/driver_location_service.dart';
import '../../services/socket_service_client.dart';
import 'hacer_oferta_screen.dart';
import 'oferta_enviada_screen.dart';


class ConductorTripDetailScreen extends StatefulWidget {
  final Map<String, dynamic> trip;
  const ConductorTripDetailScreen({super.key, required this.trip});

  @override
  State<ConductorTripDetailScreen> createState() => _ConductorTripDetailScreenState();
}

class _ConductorTripDetailScreenState extends State<ConductorTripDetailScreen> {
  bool _enviandoOferta = false;
  String? _placa;
  String? _tipoVehiculo;
  StreamSubscription<Map<String, dynamic>>? _tripStatusSub;
  StreamSubscription<Map<String, dynamic>>? _tripAcceptedSub;

  late int _secondsLeft;
  Timer? _expireTimer;

  static const Color _accentBlue = Color(0xFF2563EB);
  static const Color _green = Color(0xFF16A34A);
  static const Color _orange = Color(0xFFEA580C);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _divider = Color(0xFFE5E7EB);

  @override
  void initState() {
    super.initState();
    _secondsLeft = (widget.trip['expiresIn'] as int?) ?? 30;
    _expireTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 0) {
        t.cancel();
        if (mounted) {
          Navigator.of(context).maybePop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('La solicitud expiró')),
          );
        }
      } else {
        if (mounted) setState(() => _secondsLeft--);
      }
    });
    _fetchProfile();
    _setupSocketListeners();
  }

  void _setupSocketListeners() {
    final tripId = _tripId?.toString();

    _tripAcceptedSub = SocketServiceClient.instance.onTripAccepted.listen((data) {
      if (_matchTripId(data, tripId) && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Este viaje fue asignado a otro conductor.')),
        );
        Navigator.pop(context);
      }
    });

    _tripStatusSub = SocketServiceClient.instance.onTripStatus.listen((data) {
      if (_matchTripId(data, tripId)) {
        final estado = data['estado'] as String?;
        if (estado == 'cancelado' && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Este viaje ya no está disponible.')),
          );
          Navigator.pop(context);
        }
      }
    });
  }

  bool _matchTripId(Map<String, dynamic> data, String? tripId) {
    final id = data['tripId']?.toString() ?? data['id']?.toString();
    return id == tripId;
  }

  Future<void> _fetchProfile() async {
    try {
      final profile = await ApiClient.instance.getProfile();
      final conductor = profile['conductor'] as Map<String, dynamic>?;
      if (conductor != null && mounted) {
        setState(() {
          _placa = conductor['placa'] as String?;
          _tipoVehiculo = conductor['tipoVehiculo'] as String?;
        });
      }
    } catch (e) {
      debugPrint('Error cargando perfil conductor: $e');
    }
  }

  @override
  void dispose() {
    _expireTimer?.cancel();
    _tripStatusSub?.cancel();
    _tripAcceptedSub?.cancel();
    super.dispose();
  }

  dynamic get _tripId => widget.trip['_id'] ?? widget.trip['id'];

  String get _timerLabel {
    final m = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _showOfferSheet() async {
    if (_enviandoOferta) return;
    setState(() => _enviandoOferta = true);
    try {
      final precioEstimado = widget.trip['precioEstimado'];
      final ofertaInicial = _toNum(precioEstimado)?.toDouble() ?? 55000;
      final precioStr = precioEstimado != null ? '\$${_formatMonto(precioEstimado)}' : '\$50.000';
      final montoStr = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (_) => HacerOfertaScreen(
            tripId: _tripId,
            precioCliente: precioStr,
            ofertaInicial: ofertaInicial,
            placa: _placa,
          ),
        ),
      );
      if (montoStr != null && mounted) {
        _tripStatusSub?.cancel();
        _tripAcceptedSub?.cancel();
        DriverLocationService.instance.markAsOffered(_tripId);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => OfertaEnviadaScreen(
              montoOferta: montoStr,
              tripId: _tripId,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _enviandoOferta = false);
    }
  }

  String _formatMonto(dynamic v) {
    final n = _toNum(v);
    if (n == null) return '0';
    final s = n.toInt().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write('.');
      buffer.write(s[i]);
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.trip;
    final origen = t['origen'] as Map<String, dynamic>?;
    final destino = t['destino'] as Map<String, dynamic>?;
    final precio = (_toNum(t['precioEstimado'])?.toStringAsFixed(0) ?? '0');
    final distancia = t['distancia'] is num
        ? '${(t['distancia'] as num).toStringAsFixed(1)} km'
        : '${t['distancia'] ?? '?'}';
    final descripcionCarga = t['descripcion'] as String? ?? 'No especificada';
    final tipoVehiculoStr = _tipoVehiculo ?? t['tipoVehiculo'] as String? ?? 'No especificado';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Nueva solicitud',
          style: TextStyle(color: Color(0xFF111827), fontSize: 17, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF111827), size: 20),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  _buildPriceCard(precio),
                  const SizedBox(height: 20),
                  _buildRouteSection(origen, destino),
                  _buildDivider(),
                  _buildInfoRow('Distancia total', distancia),
                  _buildDivider(),
                  _buildInfoRow('Descripción de la carga', descripcionCarga),
                  _buildDivider(),
                  _buildInfoRow('Tipo de vehículo requerido', tipoVehiculoStr),
                  const SizedBox(height: 20),
                  _buildExpirationBanner(),
                ],
              ),
            ),
          ),
          _buildBottomButtons(),
        ],
      ),
    );
  }

  Widget _buildPriceCard(String precio) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_outline_rounded, size: 15, color: _textSecondary),
              const SizedBox(width: 6),
              const Text(
                'Precio propuesto por el cliente',
                style: TextStyle(fontSize: 12, color: _textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '\$$precio',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: _green),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteSection(Map<String, dynamic>? origen, Map<String, dynamic>? destino) {
    return Column(
      children: [
        _buildRouteRow(
          icon: Icons.location_on_outlined,
          iconColor: _accentBlue,
          label: 'Origen',
          value: origen?['direccion'] as String? ?? 'Origen',
        ),
        Padding(
          padding: const EdgeInsets.only(left: 11),
          child: Column(
            children: List.generate(
              3,
              (_) => Container(
                width: 2,
                height: 5,
                margin: const EdgeInsets.symmetric(vertical: 2),
                color: _divider,
              ),
            ),
          ),
        ),
        _buildRouteRow(
          icon: Icons.remove_circle_outline_rounded,
          iconColor: _textSecondary,
          label: 'Destino',
          value: destino?['direccion'] as String? ?? 'Destino',
        ),
      ],
    );
  }

  Widget _buildRouteRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: _textSecondary)),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF111827)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: _textSecondary)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF111827))),
        ],
      ),
    );
  }

  Widget _buildDivider() => const Divider(color: _divider, height: 1);

  Widget _buildExpirationBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'La solicitud expirará en',
            style: TextStyle(fontSize: 14, color: Color(0xFF92400E)),
          ),
          Text(
            _timerLabel,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _orange,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _divider)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: (_enviandoOferta || _placa == null) ? null : _showOfferSheet,
          style: ElevatedButton.styleFrom(
            backgroundColor: _accentBlue,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 0,
          ),
          child: _enviandoOferta
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
              : const Text(
                  'Hacer oferta',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                ),
        ),
      ),
    );
  }

  num? _toNum(dynamic v) {
    if (v == null) return null;
    if (v is num) return v;
    return num.tryParse(v.toString());
  }
}
