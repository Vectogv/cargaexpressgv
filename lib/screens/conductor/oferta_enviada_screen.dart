import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/socket_service_client.dart';
import '../../services/logger_service.dart';
import 'oferta_aceptada_screen.dart';

class OfertaEnviadaScreen extends StatefulWidget {
  final String montoOferta;
  final dynamic tripId;

  const OfertaEnviadaScreen({
    super.key,
    this.montoOferta = '\$55.000',
    this.tripId,
  });

  @override
  State<OfertaEnviadaScreen> createState() => _OfertaEnviadaScreenState();
}

class _OfertaEnviadaScreenState extends State<OfertaEnviadaScreen> {
  StreamSubscription<Map<String, dynamic>>? _acceptedSub;
  StreamSubscription<Map<String, dynamic>>? _rejectedSub;
  bool _isNavigating = false;
  bool _hasError = false;

  static const Color _accentBlue = Color(0xFF2563EB);
  static const Color _lightBlue = Color(0xFFEFF6FF);
  static const Color _textPrimary = Color(0xFF111827);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _divider = Color(0xFFE5E7EB);

  @override
  void initState() {
    super.initState();
    final tripIdStr = widget.tripId?.toString();
    if (tripIdStr == null) {
      _hasError = true;
      return;
    }

    _acceptedSub = SocketServiceClient.instance.onOfferAccepted.listen((data) {
      if (_isNavigating) return;
      final id = data['tripId']?.toString() ?? data['id']?.toString();
      LoggerService.instance.info('offer:accepted received: tripId=$id, expected=$tripIdStr, data=$data');
      if (id != tripIdStr) return;
      _redirectToAccepted(data);
    });

    _rejectedSub = SocketServiceClient.instance.onOfferRejected.listen((data) {
      if (_isNavigating) return;
      final id = data['tripId']?.toString() ?? data['id']?.toString();
      LoggerService.instance.info('offer:rejected received: tripId=$id, expected=$tripIdStr');
      if (id != tripIdStr) return;
      _isNavigating = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).maybePop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El cliente rechazó tu oferta')),
        );
      });
    });
  }

  void _redirectToAccepted(Map<String, dynamic> tripData) {
    if (_isNavigating) return;
    LoggerService.instance.info('_redirectToAccepted: navigating to OfertaAceptadaScreen');
    _isNavigating = true;
    final clienteMap = tripData['cliente'] as Map<String, dynamic>? ?? {};
    final origenMap = tripData['origen'] as Map<String, dynamic>?;
    final destinoMap = tripData['destino'] as Map<String, dynamic>?;
    final monto = tripData['monto'] is num ? '\$${_fmt((tripData['monto'] as num).toInt())}' : widget.montoOferta;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => OfertaAceptadaScreen(
            montoOferta: monto,
            cliente: ClienteData(
              nombre: clienteMap['nombre'] as String? ?? 'Cliente',
              rating: (clienteMap['rating'] as num?)?.toDouble() ?? 5.0,
              avatarUrl: clienteMap['avatar'] as String?,
            ),
            origen: origenMap?['direccion'] as String? ?? 'Origen',
            destino: destinoMap?['direccion'] as String? ?? 'Destino',
            distancia: tripData['distancia'] != null ? '${tripData['distancia']} km' : '—',
            descripcionCarga: tripData['descripcion'] as String? ?? 'No especificada',
            trip: tripData,
          ),
        ),
        (route) => route.isFirst,
      );
    });
  }

  String _fmt(int n) {
    final s = n.toString();
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
      b.write(s[i]);
    }
    return b.toString();
  }

  @override
  void dispose() {
    _acceptedSub?.cancel();
    _rejectedSub?.cancel();
    super.dispose();
  }

  void _irAOfertas() {
    if (_isNavigating) return;
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Color(0xFF111827)),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Color(0xFFDC2626)),
                const SizedBox(height: 16),
                const Text(
                  'Error al cargar la información\ndel viaje.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Color(0xFF111827)),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Volver'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 36),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          color: _lightBlue,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.send_rounded,
                          color: _accentBlue,
                          size: 46,
                        ),
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        'Oferta enviada',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: _textPrimary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: const TextStyle(
                            fontSize: 15,
                            color: _textSecondary,
                            height: 1.55,
                          ),
                          children: [
                            const TextSpan(text: 'Tu oferta de '),
                            TextSpan(
                              text: widget.montoOferta,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: _textPrimary,
                              ),
                            ),
                            const TextSpan(
                                text: ' ha sido enviada al cliente.'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Te notificaremos cuando el cliente\ntome una decisión.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: _textSecondary,
                          height: 1.55,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              child: OutlinedButton(
                onPressed: _irAOfertas,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  side: const BorderSide(color: _divider, width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Ir a mis ofertas',
                  style: TextStyle(
                    color: _accentBlue,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
