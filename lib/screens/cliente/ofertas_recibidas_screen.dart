import 'dart:async';

import 'package:flutter/material.dart';
import '../../services/api/http_client.dart' show ApiException;
import '../../services/api/offer_service.dart';
import '../../services/socket_service_client.dart';
import '../../services/server_clock.dart';

/// Cada cuánto el cliente consulta GET /api/trips/:id/offers mientras el
/// viaje sigue sin conductor (`buscando_conductor` / `pendiente`). Es el
/// respaldo del socket: en teléfonos que lo cortan en segundo plano (Honor,
/// Xiaomi…) `new:offer` se pierde y, sin esto, el cliente no veía las
/// ofertas aunque le llegara el push. Las ofertas vencen a los ~28 s, así
/// que el sondeo tiene que ser corto.
const Duration intervaloSondeoOfertas = Duration(seconds: 5);

/// Suma a [actuales] las ofertas de [nuevas] que aún no están (por `_id`/`id`).
/// Las ofertas llegan por socket (`new:offer`) y por GET /offers.
List<Map<String, dynamic>> fusionarOfertas(
    List<Map<String, dynamic>> actuales, List<Map<String, dynamic>> nuevas) {
  String? idDe(Map<String, dynamic> o) => (o['_id'] ?? o['id'])?.toString();
  final ids = actuales.map(idDe).whereType<String>().toSet();
  final r = List<Map<String, dynamic>>.from(actuales);
  for (final o in nuevas) {
    final id = idDe(o);
    if (id != null && !ids.add(id)) continue;
    r.add(Map<String, dynamic>.from(o));
  }
  return r;
}

/// Resultado con el que [OfertasRecibidasScreen] se cierra al aceptar una
/// oferta: el conductor elegido (para la celebración en el rastreo).
class OfertaAceptadaResultado {
  final Map<String, dynamic> conductor;
  const OfertaAceptadaResultado(this.conductor);
}

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
  StreamSubscription<Map<String, dynamic>>? _cancelSub;
  Timer? _ticker;
  // Sondeo de GET /offers: el socket puede estar caído (segundo plano).
  Timer? _sondeo;
  bool _sincronizando = false;
  List<Map<String, dynamic>>? _ofertasDurantePeticion;
  // Hora del servidor (`expiresAt` viene del backend): el reloj del
  // teléfono puede estar desfasado.
  DateTime _now = ServerClock.ahora();

  @override
  void initState() {
    super.initState();
    _offers = List.from(widget.ofertas);
    if (widget.tripId != null) {
      _socketSub = SocketServiceClient.instance.onNewOffer.listen((data) {
        if (!mounted) return;
        final oferta = Map<String, dynamic>.from(data);
        _ofertasDurantePeticion?.add(oferta);
        setState(() => _offers = fusionarOfertas(_offers, [oferta]));
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
      // `offer:cancelled {viajeId, ofertaId}`: el conductor re-ofertó o la
      // oferta dejó de ser válida → quitarla para no aceptar una oferta vieja.
      _cancelSub = SocketServiceClient.instance.onOfferCancelled.listen((data) {
        if (!mounted) return;
        final viajeId = data['viajeId']?.toString();
        if (viajeId != null && viajeId != widget.tripId.toString()) return;
        final ofertaId = (data['ofertaId'] ?? data['_id'] ?? data['id'])?.toString();
        if (ofertaId == null) return;
        _removeOffer(ofertaId);
      });
      // Rebuild cada segundo SOLO si hay alguna oferta con countdown visible.
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        final hasCountdown = _offers.any((o) => o['expiresAt'] is String);
        if (hasCountdown) setState(() => _now = ServerClock.ahora());
      });
      _fetchOffers();
      _sondeo = Timer.periodic(intervaloSondeoOfertas, (_) => _sincronizarConServidor());
    }
  }

  @override
  void dispose() {
    _socketSub?.cancel();
    _expirySub?.cancel();
    _cancelSub?.cancel();
    _ticker?.cancel();
    _sondeo?.cancel();
    super.dispose();
  }

  /// Deja la lista igual a las ofertas pendientes del backend (él es la
  /// regla): aparecen las que el socket no entregó y desaparecen las
  /// vencidas, rechazadas o reemplazadas. Silencioso: sin spinner ni aviso
  /// de error, y no corre mientras se acepta una oferta.
  Future<void> _sincronizarConServidor() async {
    if (!mounted || _loadingOffers || _sincronizando || _acceptingId != null) return;
    _sincronizando = true;
    final durante = _ofertasDurantePeticion = <Map<String, dynamic>>[];
    try {
      final list = await OfferService.getOffers(widget.tripId);
      if (!mounted) return;
      setState(() => _offers = fusionarOfertas(list, durante));
    } catch (_) {
      // Se conserva la lista local; el siguiente sondeo lo reintenta.
    } finally {
      _sincronizando = false;
      if (identical(_ofertasDurantePeticion, durante)) _ofertasDurantePeticion = null;
    }
  }

  void _removeOffer(String offerId) {
    final idx = _offers.indexWhere((o) => _offerId(o) == offerId);
    if (idx < 0) return;
    setState(() {
      _offers.removeAt(idx);
      if (_acceptingId == offerId) _acceptingId = null;
    });
  }

  /// [replace] = true descarta las ofertas locales y usa sólo las del
  /// servidor (tras un error al aceptar, la lista local puede estar vieja).
  Future<void> _fetchOffers({bool replace = false}) async {
    if (_loadingOffers) return;
    setState(() {
      _loadingOffers = true;
      _offersError = false;
    });
    try {
      final list = await OfferService.getOffers(widget.tripId);
      if (!mounted) return;
      setState(() {
        _offers = replace ? fusionarOfertas(list, const []) : fusionarOfertas(_offers, list);
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

  Future<void> _rechazar(String offerId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.onReject(offerId);
      if (mounted) _removeOffer(offerId);
    } on ApiException catch (e) {
      // 404: la oferta ya no está pendiente (expiró o se procesó): quitarla.
      if (e.statusCode == 404 && mounted) {
        _removeOffer(offerId);
        if (widget.tripId != null) _fetchOffers(replace: true);
        return;
      }
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Error al rechazar oferta')),
      );
    }
  }

  Future<void> _aceptar(String offerId) async {
    setState(() => _acceptingId = offerId);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.onAccept(offerId);
      if (!mounted) return;

      final offer = _offers.cast<Map<String, dynamic>?>().firstWhere(
        (o) => _offerId(o!) == offerId,
        orElse: () => null,
      );
      final conductor = offer?['conductor'] is Map
          ? Map<String, dynamic>.from(offer!['conductor'] as Map)
          : <String, dynamic>{};

      // Siempre se vuelve al ÚNICO RastreoScreen (pantalla inferior) con la
      // oferta aceptada: él muestra la celebración encima de sí mismo y sigue
      // escuchando el viaje (confirmación de entrega incluida). Si
      // `offer:accepted` llega por socket, RastreoScreen no la repite.
      Navigator.of(context).pop(OfertaAceptadaResultado(conductor));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _acceptingId = null);
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      // 400 YA_ASIGNADO: el viaje ya no acepta ofertas (se asignó o cambió
      // de estado) → volver al rastreo, que muestra el estado real.
      if (e.statusCode == 400) {
        Navigator.of(context).maybePop();
        return;
      }
      // 404: la oferta ya no existe · 409: el conductor ya no está habilitado
      // · 422: la oferta expiró → quitarla y refrescar desde el servidor.
      if (e.statusCode == 404 || e.statusCode == 409 || e.statusCode == 422) {
        _removeOffer(offerId);
        _fetchOffers(replace: true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _acceptingId = null);
      messenger.showSnackBar(
        SnackBar(content: Text('Error: ${e.toString().replaceFirst("Exception: ", "")}')),
      );
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
                        onPressed: () => _fetchOffers(),
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
                                  // Una oferta expirada no se acepta, pero sí se descarta.
                                  onPressed: isAccepting ? null : () => _rechazar(offerId ?? ''),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.black87,
                                    side: const BorderSide(color: Color(0xFFDDDDDD)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(vertical: 11),
                                  ),
                                  child: Text(expired ? 'Descartar' : 'Rechazar',
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
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
                style: const TextStyle(fontSize: 13, color: Color(0xFF2563EB), fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
