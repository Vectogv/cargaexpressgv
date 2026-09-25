import 'dart:async';

import 'package:flutter/foundation.dart';

import '../contracts/solicitud.dart';
import '../contracts/trip_status.dart';
import '../models/oferta_pendiente.dart';
import 'api_client.dart';
import 'driver_location_service.dart';
import 'logger_service.dart';
import 'server_clock.dart';
import 'socket_service_client.dart';

/// Solicitud cercana que el backend sigue teniendo en búsqueda de conductor,
/// junto con lo que este conductor ya hizo en ella.
class SolicitudDisponible {
  /// Datos del viaje (GET /api/trips/nearby o, mientras llega el sondeo, el
  /// aviso mínimo de `trip:nearby`).
  final Map<String, dynamic> viaje;

  /// Oferta pendiente de este conductor en el viaje (GET /api/drivers/offers).
  final OfertaPendiente? oferta;

  /// El cliente rechazó la última oferta de este conductor (`offer:rejected`).
  /// El backend deja ofertar de nuevo: `offer_controller.store` sólo revisa
  /// que el viaje siga abierto y que no haya otra oferta *pendiente* propia.
  final bool ofertaRechazada;

  const SolicitudDisponible({required this.viaje, this.oferta, this.ofertaRechazada = false});

  String get id => idDeViaje(viaje) ?? '';
  bool get tieneOferta => oferta != null;
}

/// Lista viva de solicitudes disponibles para el conductor: sondeo periódico
/// de GET /api/trips/nearby + GET /api/drivers/offers (respaldo del socket,
/// como hace el cliente con sus ofertas) y eventos de socket para reaccionar
/// al instante. Un servicio sólo desaparece cuando el backend deja de
/// devolverlo (lo tomó otro conductor, se canceló o venció la búsqueda):
/// ignorar el aviso o que rechacen una oferta NO lo quita.
class SolicitudesDisponiblesService {
  static final SolicitudesDisponiblesService instance = SolicitudesDisponiblesService._();
  SolicitudesDisponiblesService._();

  static const Duration intervaloSondeo = Duration(seconds: 10);

  /// Radio de búsqueda (km). Igual al radio con el que el backend avisa
  /// `trip:nearby` y al `radioOfertaKm` con el que acepta ofertas.
  static const double radioKm = 20;

  /// Un aviso de socket se conserva aunque un sondeo ya en vuelo (anterior a
  /// la creación del viaje) no lo traiga todavía.
  static const Duration _vigenciaAviso = Duration(seconds: 30);

  final List<Map<String, dynamic>> _viajes = [];
  final Map<String, OfertaPendiente> _ofertas = {};
  final Set<String> _rechazadas = {};
  final List<StreamSubscription<Map<String, dynamic>>> _subs = [];
  final _ctrl = StreamController<List<SolicitudDisponible>>.broadcast();
  Timer? _timer;
  bool _activo = false;
  bool _sincronizando = false;

  /// Se emite la lista completa cada vez que cambia.
  Stream<List<SolicitudDisponible>> get cambios => _ctrl.stream;

  /// `true` mientras el conductor está en línea y disponible.
  bool get activo => _activo;

  /// Solicitudes abiertas, más recientes primero.
  List<SolicitudDisponible> get solicitudes {
    final ahora = ServerClock.ahora();
    final lista = <SolicitudDisponible>[];
    for (final v in _viajes) {
      final id = idDeViaje(v);
      if (id == null || !solicitudSigueAbierta(v['estado'])) continue;
      final o = _ofertas[id];
      lista.add(SolicitudDisponible(
        viaje: v,
        oferta: (o != null && o.restante(ahora) != Duration.zero) ? o : null,
        ofertaRechazada: _rechazadas.contains(id),
      ));
    }
    lista.sort((a, b) => _creado(b.viaje).compareTo(_creado(a.viaje)));
    return List.unmodifiable(lista);
  }

  static DateTime _creado(Map<String, dynamic> v) =>
      DateTime.tryParse((v['createdAt'] ?? v['created_at'])?.toString() ?? '') ??
      DateTime.fromMillisecondsSinceEpoch(0);

  /// Conductor en línea y sin viaje que lo ocupe: sondea y escucha el socket.
  /// Idempotente.
  void iniciar() {
    if (_activo) return;
    _activo = true;
    final s = SocketServiceClient.instance;
    _subs.addAll([
      s.onOfferRejected.listen((e) => _ofertaRespondida(e, rechazada: true)),
      s.onOfferExpired.listen((e) => _ofertaRespondida(e, rechazada: false)),
      s.onOfferAccepted.listen((e) => quitar(e['viajeId'] ?? e['tripId'])),
      s.onTripAccepted.listen((e) => quitar(e['tripId'] ?? e['id'])),
      s.onTripCancelled.listen((e) => quitar(e['id'] ?? e['tripId'] ?? e['viajeId'])),
      s.onTripStatus.listen((e) {
        if (!solicitudSigueAbierta(e['estado'])) quitar(e['id'] ?? e['tripId']);
      }),
    ]);
    _timer = Timer.periodic(intervaloSondeo, (_) => sincronizar());
    unawaited(sincronizar());
  }

  /// Desconectado, ocupado en un viaje o sesión cerrada: deja de sondear y
  /// vacía la lista.
  void detener() {
    if (!_activo) return;
    _activo = false;
    _timer?.cancel();
    _timer = null;
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _viajes.clear();
    _ofertas.clear();
    _rechazadas.clear();
    _emitir();
  }

  /// Sondeo: viajes cercanos y ofertas propias. Si una de las dos llamadas
  /// falla se conserva lo último conocido de esa parte.
  Future<void> sincronizar() async {
    if (!_activo || _sincronizando) return;
    _sincronizando = true;
    try {
      final resultados = await Future.wait<Object?>([_cargarViajes(), _cargarOfertas()]);
      if (!_activo) return;
      final viajes = resultados[0] as List<Map<String, dynamic>>?;
      final ofertas = resultados[1] as List<OfertaPendiente>?;
      if (viajes != null) _reemplazarViajes(viajes);
      if (ofertas != null) {
        _ofertas.clear();
        for (final o in ofertas) {
          if (o.viajeId.isEmpty) continue;
          _ofertas[o.viajeId] = o;
          _rechazadas.remove(o.viajeId);
        }
      }
      if (viajes != null || ofertas != null) _emitir();
    } finally {
      _sincronizando = false;
    }
  }

  Future<List<Map<String, dynamic>>?> _cargarViajes() async {
    try {
      // Sin GPS todavía, el backend usa la última ubicación guardada del
      // conductor (trip_controller.nearby).
      final lat = DriverLocationService.instance.lastLat;
      final lng = DriverLocationService.instance.lastLng;
      return await ApiClient.instance.getNearbyTrips(lat, lng, radio: radioKm);
    } catch (e) {
      LoggerService.instance.debug('SolicitudesDisponiblesService: viajes cercanos: $e');
      return null;
    }
  }

  Future<List<OfertaPendiente>?> _cargarOfertas() async {
    try {
      final ahora = ServerClock.ahora();
      final lista = await ApiClient.instance.getMyPendingOffers();
      return lista.map(OfertaPendiente.fromJson).where((o) => o.restante(ahora) != Duration.zero).toList();
    } catch (e) {
      LoggerService.instance.debug('SolicitudesDisponiblesService: ofertas propias: $e');
      return null;
    }
  }

  void _reemplazarViajes(List<Map<String, dynamic>> nuevos) {
    final ids = nuevos.map(idDeViaje).whereType<String>().toSet();
    final limite = DateTime.now().subtract(_vigenciaAviso).millisecondsSinceEpoch;
    final avisosVigentes = _viajes.where((v) {
      final avisoAt = v['__avisoAt'];
      return avisoAt is int && avisoAt >= limite && !ids.contains(idDeViaje(v));
    }).toList();
    _viajes
      ..clear()
      ..addAll(nuevos.map((v) => Map<String, dynamic>.from(v)))
      ..addAll(avisosVigentes);
  }

  /// Aviso `trip:nearby` del socket (payload mínimo: tripId, origen como
  /// texto, precioEstimado). Entra a la lista de inmediato y se completa con
  /// el siguiente sondeo.
  void ingresarAvisoSocket(Map<String, dynamic> evento) {
    if (!_activo) return;
    final id = idDeViaje(evento);
    if (id == null) return;
    if (_viajes.any((v) => idDeViaje(v) == id)) return;
    final origen = evento['origen'];
    final destino = evento['destino'];
    _viajes.insert(0, {
      'id': id,
      '_id': id,
      'estado': evento['estado'] ?? TripStatus.buscando,
      'precioEstimado': evento['precioEstimado'],
      'origen': origen is Map ? Map<String, dynamic>.from(origen) : {'direccion': origen?.toString() ?? ''},
      if (destino is Map) 'destino': Map<String, dynamic>.from(destino),
      'createdAt': evento['createdAt']?.toString() ?? ServerClock.ahora().toIso8601String(),
      if (evento['tipoProgramacion'] != null) 'tipoProgramacion': evento['tipoProgramacion'],
      if (evento['fechaProgramada'] != null) 'fechaProgramada': evento['fechaProgramada'],
      if (evento['horaProgramada'] != null) 'horaProgramada': evento['horaProgramada'],
      '__avisoAt': DateTime.now().millisecondsSinceEpoch,
    });
    _emitir();
    unawaited(sincronizar());
  }

  /// Tras POST /api/trips/:id/offers: la tarjeta muestra la oferta enviada
  /// sin esperar al sondeo.
  void registrarOferta(dynamic tripId, {required num monto, DateTime? venceEn, String? ofertaId}) {
    final id = tripId?.toString();
    if (id == null || id.isEmpty) return;
    _ofertas[id] = OfertaPendiente(
      id: ofertaId ?? '',
      viajeId: id,
      monto: monto,
      expiresAt: venceEn,
      origen: '',
      destino: '',
    );
    _rechazadas.remove(id);
    _emitir();
  }

  /// El viaje dejó de estar disponible (lo tomó otro, se canceló, lo gané).
  void quitar(dynamic tripId) {
    final id = tripId?.toString();
    if (id == null || id.isEmpty) return;
    final habia = _viajes.length;
    _viajes.removeWhere((v) => idDeViaje(v) == id);
    final teniaOferta = _ofertas.remove(id) != null;
    final estabaRechazada = _rechazadas.remove(id);
    if (habia != _viajes.length || teniaOferta || estabaRechazada) _emitir();
  }

  void _ofertaRespondida(Map<String, dynamic> evento, {required bool rechazada}) {
    String? viajeId;
    for (final entrada in _ofertas.entries) {
      if (entrada.value.coincideCon(evento)) viajeId = entrada.key;
    }
    viajeId ??= (evento['viajeId'] ?? evento['tripId'])?.toString();
    if (viajeId == null || viajeId.isEmpty) return;
    _ofertas.remove(viajeId);
    if (rechazada) _rechazadas.add(viajeId);
    _emitir();
  }

  void _emitir() {
    if (!_ctrl.isClosed) _ctrl.add(solicitudes);
  }

  /// Pruebas: deja el servicio como recién creado.
  @visibleForTesting
  void reiniciarParaTest() => detener();
}
