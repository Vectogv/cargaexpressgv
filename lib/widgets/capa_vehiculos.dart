import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'vehiculo_mapa.dart';

/// Un vehículo que [CapaVehiculos] debe mostrar.
class VehiculoEnMapa {
  /// Identidad estable (conductor o vehículo). Sin ella se empareja con el
  /// vehículo anterior más cercano del mismo tipo.
  final String? id;
  final LatLng punto;
  final TipoVehiculoMapa tipo;
  final Color color;

  /// Rumbo real enviado por el GPS (grados desde el norte). Sin él se
  /// calcula a partir del movimiento.
  final double? rumbo;
  final String? etiqueta;
  final double tamano;
  final bool halo;

  const VehiculoEnMapa({
    required this.punto,
    this.id,
    this.tipo = TipoVehiculoMapa.camion,
    this.color = colorVehiculoAsignado,
    this.rumbo,
    this.etiqueta,
    this.tamano = 48,
    this.halo = false,
  });
}

/// Empareja los vehículos [nuevos] sin id con las posiciones [anteriores]
/// (índice → punto y tipo): de menor a mayor distancia, del mismo tipo y a no
/// más de [maxM] metros. Devuelve índice nuevo → índice anterior.
Map<int, int> emparejarPorCercania(
  List<({LatLng punto, TipoVehiculoMapa tipo})> anteriores,
  List<({LatLng punto, TipoVehiculoMapa tipo})> nuevos, {
  double maxM = 400,
}) {
  final pares = <({int n, int a, double d})>[];
  for (var n = 0; n < nuevos.length; n++) {
    for (var a = 0; a < anteriores.length; a++) {
      if (anteriores[a].tipo != nuevos[n].tipo) continue;
      final d = distanciaMetros(anteriores[a].punto, nuevos[n].punto);
      if (d <= maxM) pares.add((n: n, a: a, d: d));
    }
  }
  pares.sort((x, y) => x.d.compareTo(y.d));
  final res = <int, int>{};
  final usados = <int>{};
  for (final p in pares) {
    if (res.containsKey(p.n) || usados.contains(p.a)) continue;
    res[p.n] = p.a;
    usados.add(p.a);
  }
  return res;
}

class _Pista {
  final int clave;
  final String? id;
  VehiculoEnMapa datos;
  LatLng desde;
  LatLng hasta;
  double rumboDesde;
  double rumboHasta;
  double opacidadDesde;
  double opacidadHasta;
  // Punto desde el que se calculó el último rumbo.
  LatLng ancla;
  bool saliendo = false;

  _Pista(this.clave, this.datos, double rumbo, {double opacidad = 0})
      : id = datos.id,
        ancla = datos.punto,
        desde = datos.punto,
        hasta = datos.punto,
        rumboDesde = rumbo,
        rumboHasta = rumbo,
        opacidadDesde = opacidad,
        opacidadHasta = 1;

  LatLng punto(double t) => LatLng(
        desde.latitude + (hasta.latitude - desde.latitude) * t,
        desde.longitude + (hasta.longitude - desde.longitude) * t,
      );
  double rumbo(double t) => interpolarAngulo(rumboDesde, rumboHasta, t);
  double opacidad(double t) => opacidadDesde + (opacidadHasta - opacidadDesde) * t;
}

/// Capa de marcadores de vehículos para un [FlutterMap]: cada vehículo se
/// desliza de su posición anterior a la nueva en [duracion], girando por el
/// camino más corto, y los que aparecen o desaparecen se funden. Sólo esta
/// capa se redibuja durante la animación (no las teselas ni la ruta).
class CapaVehiculos extends StatefulWidget {
  final List<VehiculoEnMapa> vehiculos;
  final Duration duracion;

  /// Movimientos menores no cambian el rumbo (ruido del GPS).
  final double umbralRumboM;

  /// Distancia máxima para emparejar vehículos sin id entre refrescos.
  final double maxEmparejarM;

  const CapaVehiculos({
    super.key,
    required this.vehiculos,
    this.duracion = const Duration(seconds: 1),
    this.umbralRumboM = 5,
    this.maxEmparejarM = 400,
  });

  @override
  State<CapaVehiculos> createState() => _CapaVehiculosState();
}

class _CapaVehiculosState extends State<CapaVehiculos> with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(vsync: this, duration: widget.duracion)
    ..addStatusListener(_alTerminar);
  final List<_Pista> _pistas = [];
  int _siguienteClave = 0;

  @override
  void initState() {
    super.initState();
    // Los del primer frame aparecen ya visibles, sin fundido.
    for (final v in widget.vehiculos) {
      _pistas.add(_Pista(_siguienteClave++, v, v.rumbo ?? 0, opacidad: 1));
    }
    _anim.value = 1;
  }

  @override
  void didUpdateWidget(covariant CapaVehiculos old) {
    super.didUpdateWidget(old);
    if (old.duracion != widget.duracion) _anim.duration = widget.duracion;
    _actualizar(widget.vehiculos);
  }

  void _alTerminar(AnimationStatus s) {
    if (s != AnimationStatus.completed) return;
    final antes = _pistas.length;
    _pistas.removeWhere((p) => p.saliendo);
    if (_pistas.length != antes && mounted) setState(() {});
  }

  void _actualizar(List<VehiculoEnMapa> nuevos) {
    final t = _anim.value;
    final activas = _pistas.where((p) => !p.saliendo).toList();

    // 1) Emparejar: por id y, sin id, por cercanía.
    final asignadas = <int, _Pista>{};
    final libres = <_Pista>[...activas];
    for (var i = 0; i < nuevos.length; i++) {
      final id = nuevos[i].id;
      if (id == null) continue;
      final idx = libres.indexWhere((p) => p.id == id);
      if (idx >= 0) asignadas[i] = libres.removeAt(idx);
    }
    final sinIdNuevos = [for (var i = 0; i < nuevos.length; i++) if (nuevos[i].id == null && !asignadas.containsKey(i)) i];
    final sinIdViejas = libres.where((p) => p.id == null).toList();
    final pares = emparejarPorCercania(
      [for (final p in sinIdViejas) (punto: p.hasta, tipo: p.datos.tipo)],
      [for (final i in sinIdNuevos) (punto: nuevos[i].punto, tipo: nuevos[i].tipo)],
      maxM: widget.maxEmparejarM,
    );
    pares.forEach((n, a) {
      asignadas[sinIdNuevos[n]] = sinIdViejas[a];
      libres.remove(sinIdViejas[a]);
    });

    // 2) ¿Hay algo que animar?
    var cambio = libres.isNotEmpty;
    for (var i = 0; i < nuevos.length && !cambio; i++) {
      final p = asignadas[i];
      if (p == null ||
          p.hasta != nuevos[i].punto ||
          (nuevos[i].rumbo != null && nuevos[i].rumbo != p.rumboHasta)) {
        cambio = true;
      }
    }
    if (!cambio) {
      // Sólo datos visuales (etiqueta, color...): sin reiniciar la animación.
      // (build() corre justo después de didUpdateWidget).
      asignadas.forEach((i, p) => p.datos = nuevos[i]);
      return;
    }

    // 3) Congelar el estado actual como punto de partida.
    for (final p in _pistas) {
      p.desde = p.punto(t);
      p.rumboDesde = p.rumbo(t);
      p.opacidadDesde = p.opacidad(t);
    }
    for (final p in libres) {
      p.saliendo = true;
      p.opacidadHasta = 0;
      p.hasta = p.desde;
      p.rumboHasta = p.rumboDesde;
    }
    for (var i = 0; i < nuevos.length; i++) {
      final v = nuevos[i];
      final p = asignadas[i];
      if (p == null) {
        _pistas.add(_Pista(_siguienteClave++, v, v.rumbo ?? 0));
        continue;
      }
      // Rumbo desde el último punto en que se fijó: el ruido pequeño no lo
      // cambia, pero un avance lento acumulado sí.
      final calculado = rumboSiSeMovio(p.ancla, v.punto, umbralM: widget.umbralRumboM);
      if (calculado != null) p.ancla = v.punto;
      final rumbo = v.rumbo ?? calculado;
      if (rumbo != null) p.rumboHasta = rumbo;
      p.hasta = v.punto;
      p.opacidadHasta = 1;
      p.datos = v;
    }
    _anim.forward(from: 0);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final t = _anim.value;
        return MarkerLayer(markers: [
          for (final p in _pistas)
            _marcador(p, t),
        ]);
      },
    );
  }

  Marker _marcador(_Pista p, double t) {
    final d = p.datos;
    final caja = VehiculoMapa.caja(d.tamano, conEtiqueta: (d.etiqueta ?? '').trim().isNotEmpty);
    final opacidad = p.opacidad(t).clamp(0.0, 1.0);
    final vehiculo = VehiculoMapa(
      key: ValueKey('vehiculo_mapa_${p.clave}'),
      tipo: d.tipo,
      color: d.color,
      rumbo: p.rumbo(t),
      tamano: d.tamano,
      etiqueta: d.etiqueta,
      halo: d.halo,
    );
    return Marker(
      key: ValueKey(p.clave),
      point: p.punto(t),
      width: caja.width,
      height: caja.height,
      child: opacidad >= 1 ? vehiculo : Opacity(opacity: opacidad, child: vehiculo),
    );
  }
}
