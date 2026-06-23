import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api/trip_service.dart';
import '../../services/api/offer_service.dart';
import '../../services/socket_service_client.dart';
import '../../widgets/driver_nearby_warning_sheet.dart';
import 'cancel_trip_screen.dart';
import 'ofertas_recibidas_screen.dart';
import 'oferta_aceptada_screen.dart';
import 'confirmar_entrega_screen.dart';
import 'viaje_finalizado.dart';
import 'calificar_conductor_screen.dart';
import 'reportar_problema_screen.dart';
import 'conductor_en_la_zona_screen.dart';
import 'chat_screen.dart';

class RastreoScreen extends StatefulWidget {
  const RastreoScreen({super.key});

  @override
  State<RastreoScreen> createState() => _RastreoScreenState();
}

class _RastreoScreenState extends State<RastreoScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  Map<String, dynamic>? _trip;
  List<Map<String, dynamic>> _ofertas = [];
  String _status = 'buscando_conductor';
  bool _loading = false;
  bool _cancelling = false;
  bool _hasOffers = false;
  bool _offerAcceptedShown = false;
  bool _isNavigating = false;
  bool _socketListenersSetUp = false;

  StreamSubscription<Position>? _positionSub;
  StreamSubscription<Map<String, dynamic>>? _tripStatusSub;
  StreamSubscription<Map<String, dynamic>>? _tripCancelledSub;
  StreamSubscription<Map<String, dynamic>>? _newOfferSub;
  StreamSubscription<Map<String, dynamic>>? _offerAcceptedSub;
  StreamSubscription<Map<String, dynamic>>? _tripAcceptedSub;
  StreamSubscription<Map<String, dynamic>>? _driverLocationSub;
  StreamSubscription<Map<String, dynamic>>? _finalizeRequestSub;
  StreamSubscription<Map<String, dynamic>>? _tripFinalizedSub;

  Timer? _pollingTimer;
  Timer? _proximityTimer;
  bool _proximityAlertShown = false;
  bool _conductorEnLaZonaShown = false;
  double _driverLat = 0;
  double _driverLng = 0;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      if (_trip == null) {
        final active = await TripService.getActiveTrip();
        if (active != null && mounted) {
          _trip = active;
          final estado = active['estado'] as String?;
          if (estado != null) {
            setState(() => _status = estado);
          }
        }
      }

      if (!_socketListenersSetUp) {
        _setupSocketListeners();
        _socketListenersSetUp = true;
      }

      if (_trip != null && _status != 'buscando_conductor') {
        await _startLocationUpdates();
      }

      if (_status == 'buscando_conductor' && mounted) {
        _startPolling();
      }
    } catch (e) {
      debugPrint('Error en _load: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _safePop() {
    if (_isNavigating) return;
    _isNavigating = true;
    Navigator.maybePop(context).then((_) {
      _isNavigating = false;
    }).catchError((_) {
      _isNavigating = false;
    });
  }

  void _safePush(Widget screen) {
    if (_isNavigating) return;
    _isNavigating = true;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    ).then((_) {
      _isNavigating = false;
    }).catchError((_) {
      _isNavigating = false;
    });
  }

  void _safeReplace(Widget screen) {
    if (_isNavigating) return;
    _isNavigating = true;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    ).then((_) {
      _isNavigating = false;
    }).catchError((_) {
      _isNavigating = false;
    });
  }

  void _safePopUntilFirst() {
    if (_isNavigating) return;
    _isNavigating = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.popUntil(context, (route) => route.isFirst);
      _isNavigating = false;
    });
  }

  void _setupSocketListeners() {
    _tripStatusSub = SocketServiceClient.instance.onTripStatus.listen((data) {
      final newStatus = data['status'] as String?;
      if (newStatus != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() => _status = newStatus);
          if (newStatus == 'aceptado' || newStatus == 'en_curso') {
            _startLocationUpdates();
          }
        });
      }
    });

    _tripCancelledSub = SocketServiceClient.instance.onTripCancelled.listen((data) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _loading = true);
      });
      Future.delayed(const Duration(milliseconds: 600), () {
        if (!mounted) return;
        Navigator.popUntil(context, (route) => route.isFirst);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El viaje ha sido cancelado')),
        );
        if (!mounted) return;
        setState(() => _loading = false);
      });
    });

    _newOfferSub = SocketServiceClient.instance.onNewOffer.listen((data) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _hasOffers = true;
          _ofertas.add(Map<String, dynamic>.from(data));
        });
      });
    });

    _offerAcceptedSub = SocketServiceClient.instance.onOfferAccepted.listen((data) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _offerAcceptedShown) return;
        _offerAcceptedShown = true;
        final conductor = data['conductor'] as Map<String, dynamic>? ?? {};
        _safeReplace(OfertaAceptadaScreen(
          conductorNombre: conductor['nombre'] as String? ?? 'Conductor',
          camion: conductor['tipoVehiculo'] as String? ?? '',
          placa: conductor['placa'] as String? ?? '',
          rating: (conductor['rating'] as num?)?.toDouble() ?? 0,
          onVerSeguimiento: () => Navigator.pop(context),
        ));
      });
    });

    _tripAcceptedSub = SocketServiceClient.instance.onTripAccepted.listen((data) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _status = 'aceptado');
        _startLocationUpdates();
      });
    });

    _driverLocationSub = SocketServiceClient.instance.onDriverLocation.listen((data) {
      final lat = data['lat'] as double?;
      final lng = data['lng'] as double?;
      if (lat != null && lng != null) {
        _driverLat = lat;
        _driverLng = lng;
        _checkProximity();
      }
    });

    _finalizeRequestSub = SocketServiceClient.instance.onFinalizeRequest.listen((data) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showFinalizeConfirmation();
      });
    });

    _tripFinalizedSub = SocketServiceClient.instance.onTripCompleted.listen((data) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final conductor = _trip?['conductor'] as Map<String, dynamic>? ?? {};
        _safePush(ViajeFinalizado(
          trip: _trip ?? {},
          conductor: conductor,
          onCalificar: () {
            _safePush(CalificarConductorScreen(
              conductor: conductor,
              tripId: _trip?['id'] ?? '',
              onSubmitted: () {
                Navigator.popUntil(context, (route) => route.isFirst);
              },
            ));
          },
          onVolverAlInicio: () {
            Navigator.popUntil(context, (route) => route.isFirst);
          },
        ));
      });
    });
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted || _status != 'buscando_conductor') {
        _pollingTimer?.cancel();
        return;
      }
      try {
        final trip = await TripService.getActiveTrip();
        if (trip != null && mounted) {
          setState(() {
            _trip = trip;
            final estado = trip['estado'] as String?;
            if (estado == 'aceptado' || estado == 'en_curso') {
              _status = estado!;
              _pollingTimer?.cancel();
            }
          });
        }
      } catch (_) {}
    });
  }

  Future<void> _startLocationUpdates() async {
    _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((_) {});
  }

  double _distanceToPickup() {
    if (_trip == null) return double.infinity;
    final origen = _trip!['origen'] as Map<String, dynamic>?;
    if (origen == null) return double.infinity;
    final oLat = _parseDouble(origen['lat']);
    final oLng = _parseDouble(origen['lng']);
    if (oLat == null || oLng == null) return double.infinity;
    return _haversine(_driverLat, _driverLng, oLat, oLng) / 1000;
  }

  double _haversine(double lat1, double lng1, double lat2, double lng2) {
    const R = 6371000;
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) *
        sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _toRad(double deg) => deg * pi / 180;

  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }

  void _checkProximity() {
    final dist = _distanceToPickup();
    if (dist < 1.0 && !_proximityAlertShown && _status == 'aceptado') {
      _proximityAlertShown = true;
      _showProximityAlert();
    }
    if (dist < 0.05 && !_conductorEnLaZonaShown) {
      _conductorEnLaZonaShown = true;
      _showConductorEnLaZona();
    }
  }

  void _showProximityAlert() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      DriverNearbyWarningSheet.show(
        context,
        onProceed: () {
          Navigator.push<Map<String, dynamic>>(
            context,
            MaterialPageRoute(builder: (_) => const CancelTripScreen(enCurso: false)),
          ).then((result) {
            if (result != null) _doCancel();
          });
        },
      );
    });
  }

  void _showConductorEnLaZona() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final conductor = _trip?['conductor'] as Map<String, dynamic>? ?? {};
      _safePush(ConductorEnLaZonaScreen(
        conductor: conductor,
        onChat: () {
          _safePush(ChatScreen(trip: _trip ?? {}));
        },
        onCall: () async {
          final tel = conductor['telefono'] as String?;
          if (tel != null) {
            final uri = Uri.parse('tel:$tel');
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          }
        },
      ));
    });
  }

  Future<void> _doCancel() async {
    if (_cancelling) return;
    setState(() => _cancelling = true);
    try {
      await TripService.cancelTrip(_trip?['id'] ?? '', motivo: 'Cancelado por el usuario');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Viaje cancelado correctamente')),
      );
      _safePopUntilFirst();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cancelar: $e')),
      );
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  void _cancelar() {
    final dist = _distanceToPickup();
    if (dist < 1.0) {
      _showProximityAlert();
    } else {
      Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(builder: (_) => const CancelTripScreen(enCurso: false)),
      ).then((result) {
        if (result != null) {
          _doCancel();
        }
      });
    }
  }

  void _showFinalizeConfirmation() {
    _safeReplace(ConfirmarEntregaScreen(
      onConfirmar: () {
        final conductor = _trip?['conductor'] as Map<String, dynamic>? ?? {};
        _safeReplace(ViajeFinalizado(
          trip: _trip ?? {},
          conductor: conductor,
          onCalificar: () {
            _safePush(CalificarConductorScreen(
              conductor: conductor,
              tripId: _trip?['id'] ?? '',
              onSubmitted: () {
                Navigator.popUntil(context, (route) => route.isFirst);
              },
            ));
          },
          onVolverAlInicio: () {
            Navigator.popUntil(context, (route) => route.isFirst);
          },
        ));
      },
      onReportar: () {
        _safePush(ReportarProblemaScreen(
          trip: _trip,
          role: 'cliente',
          onSubmitted: () {
            _safePop();
          },
        ));
      },
    ));
  }

  String _formatDistance(double km) {
    if (km.isInfinite) return '--';
    if (km < 1) {
      return '${(km * 1000).toStringAsFixed(0)} m';
    }
    return '${km.toStringAsFixed(2)} km';
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _proximityTimer?.cancel();
    _positionSub?.cancel();
    _tripStatusSub?.cancel();
    _tripCancelledSub?.cancel();
    _newOfferSub?.cancel();
    _offerAcceptedSub?.cancel();
    _tripAcceptedSub?.cancel();
    _driverLocationSub?.cancel();
    _finalizeRequestSub?.cancel();
    _tripFinalizedSub?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          _getAppBarTitle(),
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A2E),
          ),
        ),
        actions: _buildAppBarActions(),
      ),
      body: _buildBody(),
    );
  }

  String _getAppBarTitle() {
    switch (_status) {
      case 'buscando_conductor':
        return 'Buscando conductor';
      case 'aceptado':
        return 'Conductor asignado';
      case 'en_curso':
        return 'Viaje en curso';
      case 'completado':
        return 'Viaje completado';
      default:
        return 'Rastreo';
    }
  }

  List<Widget> _buildAppBarActions() {
    if (_hasOffers && _status == 'buscando_conductor') {
      return [
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.local_offer, color: Color(0xFF1A1A2E)),
              onPressed: () {
                _safePush(OfertasRecibidasScreen(
                  ofertas: _ofertas,
                  trip: _trip ?? {},
                  onAccept: (offerId) async {
                    await OfferService.acceptOffer(_trip?['id'], offerId);
                  },
                  onReject: (offerId) async {
                    await OfferService.rejectOffer(_trip?['id'], offerId);
                  },
                ));
              },
            ),
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${_ofertas.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ];
    }
    return [];
  }

  Widget _buildBody() {
    if (_loading && _trip == null) {
      return const Center(child: CircularProgressIndicator());
    }

    switch (_status) {
      case 'buscando_conductor':
        return _buildSearchContent();
      case 'aceptado':
      case 'en_curso':
        return _buildTrackingContent();
      default:
        return _buildSearchContent();
    }
  }

  Widget _buildSearchContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(),
        _buildPulseAnimation(),
        const SizedBox(height: 24),
        const Text(
          'Buscando conductor disponible...',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF1A1A2E)),
        ),
        const SizedBox(height: 8),
        const Text(
          'Por favor espera mientras encontramos un conductor cerca de ti.',
          style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        if (_ofertas.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Card(
              child: ListTile(
                leading: const Icon(Icons.local_offer, color: Colors.green),
                title: Text('${_ofertas.length} oferta(s) recibida(s)'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  _safePush(OfertasRecibidasScreen(
                    ofertas: _ofertas,
                    trip: _trip ?? {},
                    onAccept: (offerId) async {
                      await OfferService.acceptOffer(_trip?['id'], offerId);
                    },
                    onReject: (offerId) async {
                      await OfferService.rejectOffer(_trip?['id'], offerId);
                    },
                  ));
                },
              ),
            ),
          ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.all(24),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _cancelling ? null : _cancelar,
              icon: _cancelling
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cancel_outlined),
              label: Text(_cancelling ? 'Cancelando...' : 'Cancelar búsqueda'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFE53935),
                side: const BorderSide(color: Color(0xFFE53935)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPulseAnimation() {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (ctx, child) {
        return SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              ...List.generate(3, (i) {
                final phase = (_pulseCtrl.value + i / 3) % 1.0;
                return Transform.scale(
                  scale: 0.5 + phase * 0.8,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF2563EB).withValues(alpha: 0.35 - phase * 0.3),
                    ),
                  ),
                );
              }),
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF2563EB),
                ),
                child: const Icon(Icons.search, color: Colors.white, size: 28),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTrackingContent() {
    return Stack(
      children: [
        Container(color: const Color(0xFFE5E7EB)),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _buildDriverPanel(),
        ),
      ],
    );
  }

  Widget _buildDriverPanel() {
    final conductor = _trip?['conductor'] as Map<String, dynamic>?;
    final conductorNombre = conductor?['nombre'] as String? ?? 'Conductor';
    final tipoVehiculo = conductor?['tipoVehiculo'] as String? ?? '';
    final placa = conductor?['placa'] as String? ?? '';
    final rating = (conductor?['calificacion'] as num?)?.toDouble() ?? 0;
    final telefono = conductor?['telefono'] as String?;
    final distance = _distanceToPickup();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFFE5E7EB),
                child: const Icon(Icons.person, color: Color(0xFF6B7280), size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conductorNombre,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    if (tipoVehiculo.isNotEmpty || placa.isNotEmpty)
                      Text(
                        '${tipoVehiculo.isNotEmpty ? tipoVehiculo : ''}${tipoVehiculo.isNotEmpty && placa.isNotEmpty ? ' - ' : ''}${placa.isNotEmpty ? placa : ''}',
                        style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                      ),
                  ],
                ),
              ),
              if (rating > 0)
                Row(
                  children: [
                    const Icon(Icons.star, color: Color(0xFFF59E0B), size: 20),
                    const SizedBox(width: 4),
                    Text(
                      rating.toStringAsFixed(1),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildInfoChip(Icons.access_time, '5 min'),
              const SizedBox(width: 12),
              _buildInfoChip(Icons.location_on, _formatDistance(distance)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.chat_bubble_outline,
                  label: 'Chat',
                  onTap: () {
                    _safePush(ChatScreen(trip: _trip ?? {}));
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.phone_outlined,
                  label: 'Llamar',
                  onTap: () async {
                    if (telefono != null) {
                      final uri = Uri.parse('tel:$telefono');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.cancel_outlined,
                  label: 'Cancelar',
                  onTap: _cancelling ? null : _cancelar,
                  color: const Color(0xFFE53935),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.warning_amber_outlined,
                  label: 'Reportar',
                  onTap: () {
                    _safePush(ReportarProblemaScreen(
                      trip: _trip,
                      role: 'cliente',
                      onSubmitted: () {
                        _safePop();
                      },
                    ));
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF6B7280)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color ?? const Color(0xFF2563EB), size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color ?? const Color(0xFF4B5563),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
