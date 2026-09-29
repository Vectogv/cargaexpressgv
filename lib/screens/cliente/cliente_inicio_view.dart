import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../contracts/trip_status.dart';
import '../../core/formato_dinero.dart';
import '../../services/banner_service.dart';
import '../../services/config_cliente_service.dart';
import '../shared/ui_compartida.dart';
import 'confirmar_entrega_screen.dart' show avisoConfirmacionPendiente;

const Color _kPrimary = ColoresApp.azul;
const Color _kTexto = ColoresApp.textoOscuro;
const Color _kGris = ColoresApp.textoSecundario;
const Color _kBorde = ColoresApp.borde;
const Color _kAmbar = ColoresApp.naranja;

/// Color del estado de un viaje para chips y tarjetas.
Color colorEstadoViaje(String? estado) {
  switch (estado) {
    case TripStatus.buscando:
    case TripStatus.pendiente:
    case TripStatus.creado:
    // Espera al cliente: ámbar, como el aviso de confirmación.
    case TripStatus.esperaConfirmacion:
    case TripStatus.pendienteConfirmacion:
      return _kAmbar;
    case TripStatus.aceptado:
    case TripStatus.enCamino:
    case TripStatus.llegada:
    case TripStatus.enCurso:
      return _kPrimary;
    case TripStatus.entregado:
    case TripStatus.finalizado:
      return const Color(0xFF16A34A);
    case TripStatus.disputa:
    case TripStatus.enDisputa:
      return const Color(0xFFD97706);
    case TripStatus.cancelado:
    case TripStatus.rechazado:
    case TripStatus.sos:
      return const Color(0xFFDC2626);
    default:
      return _kGris;
  }
}

/// Paso actual de la barra de progreso (Conductor asignado, Recogido, En
/// camino, Entregado) o null si el estado no tiene barra (búsqueda, reserva,
/// disputa, cancelado).
int? pasoProgresoViaje(String? estado) {
  switch (estado) {
    case TripStatus.aceptado:
    case TripStatus.enCamino:
    case TripStatus.llegada:
      return 0;
    case TripStatus.enCurso:
    case TripStatus.sos:
      return 2;
    case TripStatus.entregado:
    case TripStatus.esperaConfirmacion:
    case TripStatus.pendienteConfirmacion:
    case TripStatus.finalizado:
      return 3;
    default:
      return null;
  }
}

bool _esperaConfirmacion(String? estado) => estado == TripStatus.pendienteConfirmacion || estado == TripStatus.esperaConfirmacion;

bool _buscando(String? estado) => estado == TripStatus.buscando || estado == TripStatus.creado || estado == TripStatus.pendiente;

bool _enDisputa(String? estado) => estado == TripStatus.disputa || estado == TripStatus.enDisputa;

String _rutaCorta(Map<String, dynamic> viaje) {
  // Solo el primer tramo ("Parque Caldas, Calle 5…" → "Parque Caldas"): la
  // dirección completa ocupa las dos líneas y esconde el destino.
  String dir(dynamic p) => ((p is Map ? p['direccion']?.toString() : null) ?? '').split(',').first.trim();
  final o = dir(viaje['origen']);
  final d = dir(viaje['destino']);
  return '${o.isEmpty ? '—' : o} → ${d.isEmpty ? '—' : d}';
}

const _meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

String _fecha(String? iso) {
  final dt = DateTime.tryParse(iso ?? '')?.toLocal();
  if (dt == null) return '';
  return '${dt.day} ${_meses[dt.month - 1]} · ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
}

// precioFinal es el monto real (el aceptado con la oferta); mientras no
// haya, se muestra el estimado.
num? _num(dynamic x) => x is num ? x : num.tryParse(x?.toString() ?? '');
num? _precio(Map<String, dynamic> v) => _num(v['precioFinal']) ?? _num(v['precioEstimado']);

String _iniciales(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  return parts.isNotEmpty ? parts[0][0].toUpperCase() : '?';
}

/// Contenido del inicio del cliente (sin lógica: [ClienteHomeScreen] carga
/// los datos y navega).
class ClienteInicioView extends StatelessWidget {
  final String? nombre;
  final bool cargando;
  final bool errorActivo;
  final Map<String, dynamic>? viajeActivo;
  final List<Map<String, dynamic>> recientes;
  final bool cargandoRecientes;
  final bool errorRecientes;
  final VoidCallback onNuevoEnvio;
  final VoidCallback onVerSeguimiento;
  final ValueChanged<Map<String, dynamic>> onVerViaje;
  final VoidCallback onHistorial;
  final VoidCallback onConfirmarEntrega;
  final VoidCallback onReportarProblema;
  final VoidCallback onReintentar;
  final Future<void> Function() onRefresh;

  const ClienteInicioView({
    super.key,
    required this.nombre,
    required this.cargando,
    required this.errorActivo,
    required this.viajeActivo,
    required this.recientes,
    required this.cargandoRecientes,
    required this.errorRecientes,
    required this.onNuevoEnvio,
    required this.onVerSeguimiento,
    required this.onVerViaje,
    required this.onHistorial,
    required this.onConfirmarEntrega,
    required this.onReportarProblema,
    required this.onReintentar,
    required this.onRefresh,
  });

  String _subtitulo(String? estado) {
    if (viajeActivo == null) return '¿Qué vas a enviar hoy?';
    if (_esperaConfirmacion(estado)) return 'Tu envío llegó al destino';
    if (estado == TripStatus.enCurso) return 'Tu envío va en camino';
    if (_buscando(estado)) return 'Estamos buscando un conductor';
    if (estado == TripStatus.reservado) return 'Tienes una reserva programada';
    if (_enDisputa(estado)) return 'Tu envío está en revisión';
    return 'Tienes un envío en marcha';
  }

  String _tituloSeccion(String? estado) {
    if (_esperaConfirmacion(estado)) return 'Confirma tu entrega';
    if (estado == TripStatus.enCurso) return 'Tu envío en camino';
    return 'Tu envío';
  }

  @override
  Widget build(BuildContext context) {
    final primerNombre = (nombre ?? '').trim().split(' ').first;
    final activo = viajeActivo;
    final estado = activo?['estado'] as String?;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(
            primerNombre.isEmpty ? '¡Hola!' : '¡Hola, $primerNombre!',
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: _kTexto, letterSpacing: -0.5),
          ),
          const SizedBox(height: 4),
          Text(_subtitulo(estado), style: const TextStyle(fontSize: 15, color: _kGris)),
          const SizedBox(height: 20),
          const _BannerPlataforma(),
          if (cargando)
            const _CargandoCard()
          else ...[
            if (errorActivo) ...[
              _AvisoError(texto: 'No pudimos verificar si tienes un viaje activo. Revisa tu conexión.', onReintentar: onReintentar),
              const SizedBox(height: 16),
            ],
            // El servidor no permite dos viajes activos (409): con uno en
            // marcha no se ofrece "Nuevo envío".
            if (activo == null) ...[_NuevoEnvioCard(onTap: onNuevoEnvio), const SizedBox(height: 24)],
            _TituloSeccion(
              _tituloSeccion(estado),
              accion: activo != null && !_buscando(estado) && !_enDisputa(estado) ? 'Ver detalle ›' : null,
              onAccion: onVerSeguimiento,
            ),
            if (activo == null)
              const _SinEnvioActivo()
            else
              _ViajeActivoCard(viaje: activo, onTap: onVerSeguimiento, onConfirmar: onConfirmarEntrega, onProblema: onReportarProblema),
          ],
          const SizedBox(height: 28),
          _TituloSeccion('Último envío', accion: recientes.isNotEmpty ? 'Ver todos' : null, onAccion: onHistorial),
          if (cargandoRecientes)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5))),
            )
          else if (errorRecientes)
            _AvisoError(texto: 'No pudimos cargar tus envíos.', onReintentar: onReintentar)
          else if (recientes.isEmpty)
            const _SinEnvios()
          else
            _ViajeRecienteTile(viaje: recientes.first, onTap: () => onVerViaje(recientes.first)),
        ],
      ),
    );
  }
}

/// Banner que la gerencia configura desde el panel (Configuración → Banner).
/// Se oculta solo si no está activo o no tiene texto; sin toque si no trae
/// enlace.
class _BannerPlataforma extends StatelessWidget {
  const _BannerPlataforma();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<BannerPlataforma>(
      valueListenable: BannerService.instance.banner,
      builder: (_, banner, _) {
        if (!banner.visible) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: banner.link == null ? null : () => launchUrl(Uri.parse(banner.link!), mode: LaunchMode.externalApplication),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: ColoresApp.azulTenue,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ColoresApp.azul.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.campaign_outlined, color: ColoresApp.azul, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      banner.texto,
                      style: const TextStyle(fontSize: 13, color: ColoresApp.azulOscuro, height: 1.4, fontWeight: FontWeight.w500),
                    ),
                  ),
                  if (banner.link != null) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right_rounded, color: ColoresApp.azul, size: 20),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TituloSeccion extends StatelessWidget {
  final String titulo;
  final String? accion;
  final VoidCallback onAccion;
  const _TituloSeccion(this.titulo, {required this.accion, required this.onAccion});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              titulo,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _kTexto),
            ),
          ),
          if (accion != null)
            TextButton(
              onPressed: onAccion,
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              child: Text(
                accion!,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ColoresApp.azul),
              ),
            ),
        ],
      ),
    );
  }
}

class _CargandoCard extends StatelessWidget {
  const _CargandoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(color: ColoresApp.fondo, borderRadius: BorderRadius.circular(18)),
      alignment: Alignment.center,
      child: const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.5)),
    );
  }
}

class _NuevoEnvioCard extends StatelessWidget {
  final VoidCallback onTap;
  const _NuevoEnvioCard({required this.onTap});

  @override
  Widget build(BuildContext context) =>
      BotonPrincipal(key: const Key('btn_nuevo_envio'), texto: 'Nuevo envío', icono: Icons.add_rounded, onPressed: onTap);
}

/// Estado vacío de "Tu envío": no hay ninguno en curso.
class _SinEnvioActivo extends StatelessWidget {
  const _SinEnvioActivo();

  @override
  Widget build(BuildContext context) {
    return const TarjetaBlanca(
      padding: EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      child: Column(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: ColoresApp.azulTenue,
            child: Icon(Icons.inventory_2_outlined, size: 30, color: _kPrimary),
          ),
          SizedBox(height: 14),
          Text(
            'No tienes envíos en curso',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _kTexto),
          ),
          SizedBox(height: 4),
          Text(
            'Cuando publiques un envío, aquí verás las ofertas y el seguimiento en vivo.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: _kGris, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _ViajeActivoCard extends StatelessWidget {
  final Map<String, dynamic> viaje;
  final VoidCallback onTap;
  final VoidCallback onConfirmar;
  final VoidCallback onProblema;
  const _ViajeActivoCard({required this.viaje, required this.onTap, required this.onConfirmar, required this.onProblema});

  @override
  Widget build(BuildContext context) {
    final estado = viaje['estado'] as String?;
    final conductor = viaje['conductor'];
    final paso = pasoProgresoViaje(estado);
    final espera = _esperaConfirmacion(estado);
    final carga = (viaje['carga'] ?? viaje['descripcion'])?.toString().trim() ?? '';
    final precio = _precio(viaje);
    final pin = viaje['pinEntrega']?.toString() ?? '';
    // El PIN se pide al entregar: se muestra mientras el viaje va en camino.
    final mostrarPin = pin.isNotEmpty && paso != null && paso < 3;
    final nombreConductor = conductor is Map ? (conductor['nombre']?.toString() ?? '') : '';
    return GestureDetector(
      key: const Key('card_viaje_activo'),
      onTap: onTap,
      child: TarjetaBlanca(
        padding: const EdgeInsets.all(18),
        radio: 18,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ChipEstado(estado: estado),
            const SizedBox(height: 12),
            _Recorrido(viaje: viaje),
            const SizedBox(height: 10),
            Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                if (carga.isNotEmpty) _Dato(Icons.inventory_2_outlined, carga),
                if (espera && precio != null)
                  _Dato(Icons.payments_outlined, formatearPesos(precio))
                else
                  _Dato(Icons.calendar_today_outlined, _fecha(viaje['createdAt']?.toString())),
              ],
            ),
            if (nombreConductor.isNotEmpty && !espera) ...[const SizedBox(height: 14), _ConductorRow(conductor: Map<String, dynamic>.from(conductor as Map))],
            if (paso != null) ...[const SizedBox(height: 18), _Progreso(actual: paso)],
            if (espera) ...[
              const SizedBox(height: 16),
              _AvisoConfirmacion(conductor: nombreConductor),
              const SizedBox(height: 14),
              // Uno debajo del otro: lado a lado, en 360 dp el texto se cortaba.
              BotonPrincipal(key: const Key('btn_confirmar_entrega_inicio'), texto: 'Confirmar entrega', alto: 48, onPressed: onConfirmar),
              const SizedBox(height: 10),
              BotonSecundario(key: const Key('btn_problema_entrega'), texto: 'Hay un problema', color: ColoresApp.rojo, alto: 48, onPressed: onProblema),
            ] else if (mostrarPin) ...[
              const SizedBox(height: 16),
              _PinEntrega(pin: pin),
            ],
            if (paso != null && !espera) ...[
              const SizedBox(height: 14),
              BotonSecundario(key: const Key('btn_ver_mapa'), texto: 'Ver en el mapa', icono: Icons.map_outlined, alto: 48, onPressed: onTap),
            ],
            if (_buscando(estado) || _enDisputa(estado)) ...[
              const SizedBox(height: 16),
              BotonPrincipal(
                texto: _enDisputa(estado) ? 'Ver estado del caso' : 'Ver ofertas',
                icono: _enDisputa(estado) ? Icons.gavel_rounded : Icons.local_offer_outlined,
                alto: 46,
                onPressed: onTap,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  final IconData icon;
  final String texto;
  const _Dato(this.icon, this.texto);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: _kGris),
        const SizedBox(width: 5),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 180),
          child: Text(
            texto,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: _kGris),
          ),
        ),
      ],
    );
  }
}

class _ConductorRow extends StatelessWidget {
  final Map<String, dynamic> conductor;
  const _ConductorRow({required this.conductor});

  @override
  Widget build(BuildContext context) {
    final nombre = conductor['nombre'].toString();
    final calificacion = _num(conductor['calificacion']);
    final linea2 = [
      if (calificacion != null && calificacion > 0) '★ ${calificacion.toStringAsFixed(1)}',
      conductor['tipoVehiculo'],
    ].where((e) => e != null && e.toString().isNotEmpty).join(' · ');
    final placa = conductor['placa']?.toString() ?? '';
    final telefono = conductor['telefono']?.toString() ?? '';
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: ColoresApp.fondoPin, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: ColoresApp.azulMarino,
            child: Text(
              _iniciales(nombre),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: _kTexto),
                ),
                if (placa.isNotEmpty || linea2.isNotEmpty) const SizedBox(height: 4),
                Row(
                  children: [
                    if (placa.isNotEmpty) ...[_Placa(placa), const SizedBox(width: 8)],
                    if (linea2.isNotEmpty)
                      Flexible(
                        child: Text(
                          linea2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: _kGris),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (telefono.isNotEmpty)
            IconButton.filled(
              key: const Key('btn_llamar_conductor'),
              tooltip: 'Llamar al conductor',
              style: IconButton.styleFrom(backgroundColor: ColoresApp.azulTenue, foregroundColor: ColoresApp.azul),
              onPressed: () => launchUrl(Uri.parse('tel:$telefono'), mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.call_outlined, size: 20),
            ),
        ],
      ),
    );
  }
}

/// Placa colombiana: amarilla con letras negras.
class _Placa extends StatelessWidget {
  final String placa;
  const _Placa(this.placa);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: ColoresApp.placaFondo,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: ColoresApp.placaTexto, width: 1),
      ),
      child: Text(
        placa.toUpperCase(),
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ColoresApp.placaTexto, letterSpacing: 1, fontFeatures: cifrasTabulares),
      ),
    );
  }
}

/// Recoge / Entrega con la línea de puntos entre los dos.
class _Recorrido extends StatelessWidget {
  final Map<String, dynamic> viaje;
  const _Recorrido({required this.viaje});

  @override
  Widget build(BuildContext context) {
    String dir(dynamic p) => ((p is Map ? p['direccion']?.toString() : null) ?? '').split(',').first.trim();
    Widget punto(String etiqueta, String direccion, Color color) => Row(
          children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 12),
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: '$etiqueta  ', style: const TextStyle(fontSize: 12, color: _kGris)),
                  TextSpan(
                    text: direccion.isEmpty ? '—' : direccion,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _kTexto),
                  ),
                ]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        punto('Recoge', dir(viaje['origen']), _kPrimary),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Container(width: 2, height: 14, color: _kBorde),
        ),
        punto('Entrega', dir(viaje['destino']), _kTexto),
      ],
    );
  }
}

/// Barra de 4 pasos: los anteriores a [actual] van con check, [actual] con
/// el círculo resaltado y los siguientes en gris.
class _Progreso extends StatelessWidget {
  final int actual;
  const _Progreso({required this.actual});

  static const _pasos = ['Conductor\nasignado', 'Recogido', 'En camino', 'Entregado'];

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const Key('progreso_viaje'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _pasos.length; i++)
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _linea(visible: i > 0, activa: i <= actual),
                    ),
                    _circulo(i),
                    Expanded(
                      child: _linea(visible: i < _pasos.length - 1, activa: i < actual),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _pasos[i],
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.2,
                    fontWeight: i == actual ? FontWeight.w700 : FontWeight.w500,
                    color: i == actual ? _kPrimary : (i < actual ? _kTexto : _kGris),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _linea({required bool visible, required bool activa}) => Container(height: 3, color: !visible ? Colors.transparent : (activa ? _kPrimary : _kBorde));

  Widget _circulo(int i) {
    if (i < actual) {
      return const CircleAvatar(
        radius: 12,
        backgroundColor: _kPrimary,
        child: Icon(Icons.check_rounded, size: 15, color: Colors.white),
      );
    }
    if (i == actual) {
      return Container(
        width: 24,
        height: 24,
        decoration: const BoxDecoration(color: _kPrimary, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Container(
          width: 9,
          height: 9,
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        ),
      );
    }
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _kBorde, width: 3),
      ),
    );
  }
}

/// PIN de 4 dígitos que el cliente le dicta al conductor al recibir la carga
/// (`pinEntrega`, sólo lo manda el backend al cliente).
class _PinEntrega extends StatelessWidget {
  final String pin;
  const _PinEntrega({required this.pin});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: ColoresApp.fondoPin,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColoresApp.bordeCampo),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PIN de entrega',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kTexto),
                ),
                SizedBox(height: 2),
                Text('Dáselo al conductor cuando recibas todo', style: TextStyle(fontSize: 12, color: _kGris, height: 1.3)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            pin,
            key: const Key('pin_entrega_inicio'),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: _kTexto, letterSpacing: 6, fontFeatures: cifrasTabulares),
          ),
        ],
      ),
    );
  }
}

/// Aviso ámbar de la entrega por confirmar; el plazo viene de las reglas del
/// backend (GET /api/config/cliente).
class _AvisoConfirmacion extends StatelessWidget {
  final String conductor;
  const _AvisoConfirmacion({required this.conductor});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ReglasCliente>(
      valueListenable: ConfigClienteService.instance.reglas,
      builder: (_, reglas, _) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ColoresApp.naranjaFondo,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ColoresApp.naranjaBorde),
        ),
        child: Text(
          '${conductor.isEmpty ? 'El conductor' : conductor} marcó la entrega. Revisa tu carga y confirma. '
          '${avisoConfirmacionPendiente(reglas.confirmacionTimeoutMin)}',
          style: const TextStyle(fontSize: 13, color: ColoresApp.naranjaAviso, height: 1.4),
        ),
      ),
    );
  }
}

class _ChipEstado extends StatelessWidget {
  final String? estado;
  const _ChipEstado({required this.estado});

  @override
  Widget build(BuildContext context) {
    final color = colorEstadoViaje(estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(
        TripStatus.label(estado),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

class _ViajeRecienteTile extends StatelessWidget {
  final Map<String, dynamic> viaje;
  final VoidCallback onTap;
  const _ViajeRecienteTile({required this.viaje, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final estado = viaje['estado'] as String?;
    final monto = _precio(viaje);
    final detalle = [_fecha(viaje['createdAt']?.toString()), if (monto != null) formatearPesos(monto)].where((s) => s.isNotEmpty).join(' · ');
    return GestureDetector(
      key: const Key('tile_ultimo_envio'),
      onTap: onTap,
      child: TarjetaBlanca(
        child: Row(
          children: [
            const CircleAvatar(
              radius: 22,
              backgroundColor: ColoresApp.fondo,
              child: Icon(Icons.inventory_2_outlined, color: _kGris, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _rutaCorta(viaje),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _kTexto, height: 1.3),
                  ),
                  if (detalle.isNotEmpty) ...[const SizedBox(height: 3), Text(detalle, style: const TextStyle(fontSize: 12, color: _kGris))],
                ],
              ),
            ),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 96),
              child: Text(
                TripStatus.label(estado),
                textAlign: TextAlign.end,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: colorEstadoViaje(estado)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SinEnvios extends StatelessWidget {
  const _SinEnvios();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: ColoresApp.fondoPin,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorde),
      ),
      child: const Column(
        children: [
          Icon(Icons.inventory_2_outlined, size: 40, color: ColoresApp.chevron),
          SizedBox(height: 10),
          Text(
            'Aún no tienes envíos',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _kTexto),
          ),
          SizedBox(height: 4),
          Text(
            'Cuando solicites uno, aparecerá aquí.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: _kGris),
          ),
        ],
      ),
    );
  }
}

class _AvisoError extends StatelessWidget {
  final String texto;
  final VoidCallback onReintentar;
  const _AvisoError({required this.texto, required this.onReintentar});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: ColoresApp.naranjaFondo,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColoresApp.naranjaBorde),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, size: 18, color: ColoresApp.naranjaTexto),
          const SizedBox(width: 10),
          Expanded(
            child: Text(texto, style: const TextStyle(fontSize: 13, color: ColoresApp.naranjaAviso)),
          ),
          TextButton(onPressed: onReintentar, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}
