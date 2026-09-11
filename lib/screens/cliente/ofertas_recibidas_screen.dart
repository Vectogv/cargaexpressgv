import 'dart:async';

import 'package:flutter/material.dart';
import '../../services/api/offer_service.dart';
import '../../services/socket_service_client.dart';
import 'oferta_aceptada_screen.dart';

class OfertasRecibidasScreen extends StatefulWidget {
  final List<Map<String, dynamic>> ofertas;
  final Map<String, dynamic> trip;
  final dynamic tripId;
  final Future<void> Function(String offerId) onAccept;
  final Future<void> Function(String offerId) onReject;

  const OfertasRecibidasScreen({
    super.key,
    required this.ofertas,
    required this.trip,
    this.tripId,
    required this.onAccept,
    required this.onReject,
  });

  @override
  State<OfertasRecibidasScreen> createState() => _OfertasRecibidasScreenState();
}

class _OfertasRecibidasScreenState extends State<OfertasRecibidasScreen> {
  late List<Map<String, dynamic>> _offers;
  String? _acceptingId;
  bool _loadingOffers = false;
  bool _offersError = false;
  StreamSubscription<Map<String, dynamic>>? _socketSub;
  StreamSubscription<Map<String, dynamic>>? _expirySub;
  Timer? _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _offers = List.from(widget.ofertas);
    if (widget.tripId != null) {
      _socketSub = SocketServiceClient.instance.onNewOffer.listen((data) {
        if (!mounted) return;
        final id = (data['_id'] ?? data['id'])?.toString();
        setState(() {
          final already = _offers.any((o) => (o['_id'] ?? o['id'])?.toString() == id);
          if (!already) _offers.add(Map<String, dynamic>.from(data));
        });
      });
      // `trip:offer_received` es el alias del backend con expiraAt (28s).
      // Actualiza la oferta existente para alimentar el countdown.
      _expirySub = SocketServiceClient.instance.onTripOfferReceived.listen((data) {
        if (!mounted) return;
        final id = (data['_id'] ?? data['id'])?.toString();
        setState(() {
          final idx = _offers.indexWhere((o) => (o['_id'] ?? o['id'])?.toString() == id);
          if (idx >= 0) {
            _offers[idx] = Map<String, dynamic>.from(data);
          }
        });
      });
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _now = DateTime.now());
      });
      _fetchOffers();
    }
  }

  @override
  void dispose() {
    _socketSub?.cancel();
    _expirySub?.cancel();
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _fetchOffers() async {
    if (_loadingOffers) return;
    setState(() {
      _loadingOffers = true;
      _offersError = false;
    });
    try {
      final list = await OfferService.getOffers(widget.tripId);
      if (!mounted) return;
      setState(() {
        final ids = <String>{};
        for (final offer in _offers) {
          final id = (offer['_id'] ?? offer['id'])?.toString();
          if (id != null) ids.add(id);
        }
        final merged = List<Map<String, dynamic>>.from(_offers);
        for (final offer in list) {
          final id = (offer['_id'] ?? offer['id'])?.toString();
          if (id == null || !ids.contains(id)) {
            merged.add(Map<String, dynamic>.from(offer));
          }
        }
        _offers = merged;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _offersError = _offers.isEmpty);
    } finally {
      if (mounted) setState(() => _loadingOffers = false);
    }
  }

  Color _avatarColor(String name) {
    final hash = name.hashCode;
    final colors = [
      const Color(0xFF7B5EA7),
      const Color(0xFF4A90A4),
      const Color(0xFF8B6914),
      const Color(0xFFC0392B),
      const Color(0xFF2E86AB),
      const Color(0xFFA23B72),
    ];
    return colors[(hash % colors.length).abs()];
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  String _formatPrecio(num monto) {
    return '\$${monto.toStringAsFixed(0)}';
  }

  String? _offerId(Map<String, dynamic> offer) =>
      (offer['_id'] ?? offer['id'])?.toString();

  Future<void> _rechazar(String offerId, int index) async {
    try {
      await widget.onReject(offerId);
      if (mounted) {
        setState(() => _offers.removeAt(index));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al rechazar oferta')),
        );
      }
    }
  }

  Future<void> _aceptar(String offerId) async {
    setState(() => _acceptingId = offerId);
    try {
      await widget.onAccept(offerId);
      if (!mounted) return;

      final offer = _offers.cast<Map<String, dynamic>?>().firstWhere(
        (o) => _offerId(o!) == offerId,
        orElse: () => null,
      );
      final conductor = offer?['conductor'] as Map<String, dynamic>?;

      // RastreoScreen (pantalla inferior) ya escucha `offer:accepted` y
      // reemplaza la ruta con OfertaAceptadaScreen. Para evitar DOBLE push
      // (éste + el del socket), volvemos a RastreoScreen y dejamos que el
      // socket tome el control. Si el socket no está conectado, navegamos
      // manualmente como respaldo.
      if (SocketServiceClient.instance.isConnected) {
        Navigator.of(context).pop();
      } else {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OfertaAceptadaScreen(
              conductorNombre: conductor?['nombre'] as String? ?? 'Conductor',
              camion: conductor?['tipoVehiculo'] as String? ?? '',
              placa: conductor?['placa']?.toString() ?? '',
              rating: (conductor?['rating'] as num?)?.toDouble() ?? 0,
              onVerSeguimiento: () => Navigator.pop(context),
            ),
          ),
        );
      }
      if (mounted) {
        setState(() => _acceptingId = null);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _acceptingId = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString().replaceFirst("Exception: ", "")}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final presupuesto = num.tryParse(widget.trip['precioEstimado']?.toString() ?? '') ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.chevron_left_rounded, size: 28, color: Colors.black87),
                    ),
                  ),
                  Text(
                    'Ofertas recibidas (${_offers.length})',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),

            if (_loadingOffers && _offers.isEmpty)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_offersError && _offers.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('No se pudieron cargar las ofertas', style: TextStyle(color: Colors.black45, fontSize: 15)),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _fetchOffers,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              )
            else if (_offers.isEmpty)
              const Expanded(
                child: Center(
                  child: Text('No hay ofertas disponibles', style: TextStyle(color: Colors.black45, fontSize: 15)),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: _offers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final offer = _offers[i];
                    final offerId = _offerId(offer);
                    final conductor = offer['conductor'] as Map<String, dynamic>?;
                    final nombre = conductor?['nombre'] as String? ?? 'Conductor';
                    final camion = '${conductor?['tipoVehiculo'] ?? ''} · ${conductor?['placa']?.toString() ?? ''}';
                    final monto = num.tryParse(offer['monto']?.toString() ?? '') ?? 0;
                    final diff = presupuesto > 0 ? ((monto - presupuesto) / presupuesto * 100).round() : 0;
                    final isAccepting = _acceptingId == offerId;

                    final expiresRaw = offer['expiresAt'];
                    final expiresAt = expiresRaw is String ? DateTime.tryParse(expiresRaw) : null;
                    final remaining = expiresAt?.difference(_now).inSeconds;
                    final expired = remaining != null && remaining <= 0;
                    final showCountdown = expiresAt != null && !expired;

                    return Container(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 26,
                                backgroundColor: _avatarColor(nombre),
                                child: Text(
                                  _initials(nombre),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(nombre, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black87)),
                                    const SizedBox(height: 3),
                                    Text(
                                      camion,
                                      style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w400),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 3),
                                      child: Text(
                                        diff < 0 ? 'Bajo presupuesto' : diff == 0 ? 'Igual al presupuesto' : '+$diff% sobre presupuesto',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: diff <= 10 ? const Color(0xFF22C55E) : const Color(0xFFE65100),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Text(
                                _formatPrecio(monto),
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black87, letterSpacing: -0.5),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          if (expired)
                            Row(
                              children: [
                                const Icon(Icons.timer_off_outlined, size: 16, color: Color(0xFFDC2626)),
                                const SizedBox(width: 6),
                                Text(
                                  'Oferta expirada',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.red[600],
                                  ),
                                ),
                              ],
                            )
                          else if (showCountdown)
                            Row(
                              children: [
                                const Icon(Icons.timer_outlined, size: 16, color: Color(0xFF2563EB)),
                                const SizedBox(width: 6),
                                Text(
                                  'Expira en $remaining s',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF2563EB),
                                  ),
                                ),
                              ],
                            )
                          else
                            const SizedBox.shrink(),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: isAccepting || expired ? null : () => _rechazar(offerId ?? '', i),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.black87,
                                    side: const BorderSide(color: Color(0xFFDDDDDD)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(vertical: 11),
                                  ),
                                  child: const Text('Rechazar', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: isAccepting || expired ? null : () => _aceptar(offerId ?? ''),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF22C55E),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(vertical: 11),
                                  ),
                                  child: isAccepting
                                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                      : const Text('Aceptar', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

            Padding(
              padding: const EdgeInsets.only(bottom: 24, top: 8),
              child: Text(
                'Elige la mejor oferta para ti.',
                style: TextStyle(fontSize: 13, color: const Color(0xFF2563EB), fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
