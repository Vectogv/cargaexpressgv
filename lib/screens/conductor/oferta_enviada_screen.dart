import 'dart:async';
import 'package:flutter/material.dart';
import '../../contracts/trip_status.dart';
import '../../services/socket_service_client.dart';
import '../../services/api_client.dart';
import '../../models/oferta_pendiente.dart' show formatoCuentaRegresiva;
import '../../services/logger_service.dart';
import '../../services/server_clock.dart';
import 'oferta_aceptada_screen.dart';
import 'offers_screen.dart';

class OfertaEnviadaScreen extends StatefulWidget {
  final String montoOferta;
  final dynamic tripId;

  /// Vencimiento de la oferta en hora del servidor (de `expiresAt` al
  /// crearla). Null si no se conoce: se usa un plazo de respaldo.
  final DateTime? venceEn;

  const OfertaEnviadaScreen({
    super.key,
    this.montoOferta = '—',
    this.tripId,
    this.venceEn,
  });

  @override
  State<OfertaEnviadaScreen> createState() => _OfertaEnviadaScreenState();
}

class _OfertaEnviadaScreenState extends State<OfertaEnviadaScreen> {
  StreamSubscription<Map<String, dynamic>>? _acceptedSub;
  StreamSubscription<Map<String, dynamic>>? _rejectedSub;
  StreamSubscription<Map<String, dynamic>>? _expiredSub;
  bool _isNavigating = false;
  bool _hasError = false;
  Timer? _pollTimer;
  Timer? _timeoutTimer;
  Timer? _relojTimer;

  /// Margen tras el vencimiento para que llegue offer:accepted/offer:expired
  /// antes de consultar el viaje.
  static const Duration _margenVencimiento = Duration(seconds: 3);

  /// Sin `expiresAt`: la oferta vence a los ~28 s y el backend la expira en
  /// su siguiente pasada (cada 30 s).
  static const Duration _plazoRespaldo = Duration(seconds: 90);

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

    _acceptedSub = SocketServiceClient.instance.onOfferAccepted.listen((data) async {
      if (_isNavigating) return;
      final id = data['viajeId']?.toString() ?? data['tripId']?.toString() ?? data['id']?.toString();
      LoggerService.instance.info('offer:accepted received: tripId=$id, expected=$tripIdStr, data=$data');
      if (id != tripIdStr) return;
      await _redirectToAccepted(data);
    });

    _rejectedSub = SocketServiceClient.instance.onOfferRejected.listen((data) {
      final id = data['viajeId']?.toString() ?? data['tripId']?.toString() ?? data['id']?.toString();
      LoggerService.instance.info('offer:rejected received: tripId=$id, expected=$tripIdStr');
      if (id != tripIdStr) return;
      _salir('El cliente rechazó tu oferta');
    });

    // El backend expira las ofertas pendientes sin respuesta (~28 s) y avisa
    // al conductor: se vuelve a la lista para que pueda ofertar de nuevo.
    _expiredSub = SocketServiceClient.instance.onOfferExpired.listen((data) {
      final id = data['viajeId']?.toString() ?? data['tripId']?.toString();
      if (id != tripIdStr) return;
      _salir('Tu oferta expiró sin respuesta del cliente. Puedes enviar una nueva.');
    });

    // Polling de respaldo cada 30 segundos (por si el socket falla)
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (_isNavigating || !mounted) return;
      try {
        final tripId = widget.tripId?.toString();
        if (tripId == null || tripId.isEmpty) return;
        final detail = await ApiClient.instance.getTripDetail(tripId);
        final estado = detail['estado'] as String?;
        if ((estado == TripStatus.aceptado || estado == TripStatus.enCamino || estado == TripStatus.llegada || estado == TripStatus.enCurso) && !_isNavigating && mounted) {
          await _redirectToAccepted({...detail, 'viajeId': tripId});
        } else if ((estado == TripStatus.cancelado || estado == 'expirado') && !_isNavigating && mounted) {
          _isNavigating = true;
          Navigator.maybePop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('El viaje ya no está disponible')),
          );
        }
      } catch (_) {}
    });

    // Al vencer (expiresAt del servidor) sin que llegue offer:expired ni
    // offer:accepted (socket caído), se consulta el viaje y se sale.
    final venceEn = widget.venceEn;
    final plazo = venceEn != null
        ? _restante(venceEn) + _margenVencimiento
        : _plazoRespaldo;
    if (venceEn != null) {
      _relojTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
    _timeoutTimer = Timer(plazo, () async {
      if (_isNavigating || !mounted) return;
      try {
        final detail = await ApiClient.instance.getTripDetail(tripIdStr);
        final estado = detail['estado'] as String?;
        if (estado == TripStatus.aceptado || estado == TripStatus.enCamino || estado == TripStatus.llegada || estado == TripStatus.enCurso) {
          await _redirectToAccepted({...detail, 'viajeId': tripIdStr});
          return;
        }
      } catch (_) {}
      _salir('Tu oferta expiró sin respuesta del cliente. Puedes enviar una nueva.');
    });
  }

  static Duration _restante(DateTime venceEn) {
    final r = venceEn.difference(ServerClock.ahora());
    return r.isNegative ? Duration.zero : r;
  }

  /// Sale de la pantalla (una sola vez) mostrando [mensaje]. Se llama desde
  /// eventos de socket/timers (fuera de build): sin addPostFrameCallback, que
  /// en una pantalla quieta no corre hasta que algo pida un frame.
  void _salir(String mensaje) {
    if (_isNavigating || !mounted) return;
    _isNavigating = true;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).maybePop();
    messenger.showSnackBar(SnackBar(content: Text(mensaje)));
  }

  Future<void> _redirectToAccepted(Map<String, dynamic> tripData) async {
    if (_isNavigating) return;
    LoggerService.instance.info('_redirectToAccepted: fetching trip detail');
    _isNavigating = true;

    final viajeId = tripData['viajeId']?.toString() ?? tripData['tripId']?.toString() ?? tripData['id']?.toString();

    Map<String, dynamic> fullTrip;
    try {
      fullTrip = await ApiClient.instance.getTripDetail(viajeId);
    } catch (e) {
      LoggerService.instance.error('_redirectToAccepted: getTripDetail failed', e);
      fullTrip = tripData;
    }

    final monto = tripData['monto'] is num ? '\$${_fmt((tripData['monto'] as num).toInt())}' : widget.montoOferta;

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => OfertaAceptadaScreen.desdeViaje(fullTrip, montoOferta: monto),
      ),
      (route) => route.isFirst,
    );
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
    _expiredSub?.cancel();
    _pollTimer?.cancel();
    _timeoutTimer?.cancel();
    _relojTimer?.cancel();
    super.dispose();
  }

  /// "Mis ofertas" también sigue la oferta (cuenta regresiva y respuesta).
  void _irAOfertas() {
    if (_isNavigating) return;
    _isNavigating = true;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const OffersScreen()));
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
                      if (widget.venceEn != null) ...[
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: _lightBlue,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.timer_outlined, size: 18, color: _accentBlue),
                            const SizedBox(width: 6),
                            Text(
                              'Vence en ${formatoCuentaRegresiva(_restante(widget.venceEn!))}',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _accentBlue),
                            ),
                          ]),
                        ),
                      ],
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
