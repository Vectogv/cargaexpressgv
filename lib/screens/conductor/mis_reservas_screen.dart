import 'package:flutter/material.dart';

import '../../contracts/solicitud.dart' show idDeViaje;
import '../../core/formato_dinero.dart';
import '../../services/api/http_client.dart' show ApiException;
import '../../services/api_client.dart';
import '../../services/api/trip_service.dart';
import '../../widgets/error_carga.dart';
import '../cliente/rastreo_ui.dart' show formatoFechaHoraReserva;
import '../shared/ui_compartida.dart';
import 'trip_chat_screen.dart';

/// Reservas que el cliente ya asignó a este conductor (`reservado` con
/// conductor, `GET /api/trips/reservations`). Mientras no se activen
/// (45 min antes de la recogida) solo hay chat: sin mapa ni teléfono.
class MisReservasScreen extends StatefulWidget {
  const MisReservasScreen({super.key});

  @override
  State<MisReservasScreen> createState() => _MisReservasScreenState();
}

class _MisReservasScreenState extends State<MisReservasScreen> {
  List<Map<String, dynamic>> _reservas = [];
  bool _loading = true;
  String? _error;
  String? _cancelandoId;
  String? _pidiendoPlazoId;
  final _motivoCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _motivoCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    if (mounted && !_loading) setState(() { _loading = true; _error = null; });
    try {
      final lista = await ApiClient.instance.getReservations(limit: 50, estado: 'reservado');
      if (mounted) setState(() { _reservas = lista; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = mensajeDeError(e); });
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _cancelar(Map<String, dynamic> r) async {
    final id = idDeViaje(r);
    if (id == null || _cancelandoId != null) return;
    final motivoCtrl = _motivoCtrl..clear();
    String? motivoSeleccionado;
    String justificacion = '';
    final confirmado = await mostrarHojaApp<bool>(
      context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TituloHoja(titulo: '¿Por qué cancelas la reserva?', detalle: 'El cliente verá el motivo y la reserva vuelve a abrirse para otros conductores.'),
            const SizedBox(height: 12),
            for (final m in const ['Vehículo no disponible', 'Emergencia', 'No podré llegar a tiempo', 'Otro']) ...[
              OpcionRadio(texto: m, elegida: motivoSeleccionado == m, onTap: () => setDialogState(() => motivoSeleccionado = m)),
              const SizedBox(height: 8),
            ],
            if (motivoSeleccionado != null) ...[
              const SizedBox(height: 4),
              const Text('Cuéntanos un poco más', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ColoresApp.etiquetaCampo)),
              const SizedBox(height: 6),
              TextField(
                key: const Key('reserva_justificacion'),
                controller: motivoCtrl,
                maxLines: 3,
                maxLength: 300,
                decoration: const InputDecoration(hintText: 'Mínimo 10 caracteres', counterText: ''),
                onChanged: (v) => setDialogState(() => justificacion = v.trim()),
              ),
              const SizedBox(height: 12),
            ],
            const CajaAviso(texto: 'Si faltan menos de 24 h se resta 0,5 a tu calificación.'),
            const SizedBox(height: 12),
            BotonPrincipal(
              key: const Key('reserva_confirmar_cancelar'),
              texto: 'Sí, cancelar reserva',
              color: ColoresApp.rojo,
              onPressed: (motivoSeleccionado != null && justificacion.length >= 10) ? () => Navigator.pop(ctx, true) : null,
            ),
            const SizedBox(height: 8),
            BotonSecundario(texto: 'Volver', color: ColoresApp.textoOscuro, colorBorde: ColoresApp.borde, onPressed: () => Navigator.pop(ctx, false)),
          ],
        ),
      ),
    );
    if (confirmado != true || motivoSeleccionado == null || !mounted) return;
    setState(() => _cancelandoId = id);
    try {
      final resp = await TripService.cancelTrip(id, motivo: '$motivoSeleccionado: $justificacion', justificacion: justificacion);
      if (!mounted) return;
      _snack(resp['penalizado'] == true
          ? 'Reserva cancelada. Se restó 0,5 a tu calificación.'
          : 'Reserva cancelada. El cliente fue avisado.');
      setState(() => _reservas = _reservas.where((x) => idDeViaje(x) != id).toList());
    } on ApiException catch (e) {
      if (mounted) _snack(e.code == 'JUSTIFICACION_REQUERIDA' ? 'Justificación requerida (mínimo 10 caracteres).' : e.message);
    } catch (e) {
      if (mounted) _snack(mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _cancelandoId = null);
    }
  }

  Future<void> _pedirPlazo(Map<String, dynamic> r) async {
    final id = idDeViaje(r);
    if (id == null || _pidiendoPlazoId != null) return;
    int? minutosSeleccionados;
    final minutos = await mostrarHojaApp<int>(
      context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TituloHoja(titulo: '¿Cuánto más necesitas?', detalle: 'Solo puedes pedirlo una vez. El cliente debe aceptarlo.'),
            const SizedBox(height: 12),
            for (final m in const [15, 30, 60]) ...[
              OpcionRadio(texto: '+$m min', elegida: minutosSeleccionados == m, onTap: () => setDialogState(() => minutosSeleccionados = m)),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 4),
            BotonPrincipal(
              key: const Key('reserva_confirmar_plazo'),
              texto: 'Pedir',
              onPressed: minutosSeleccionados != null ? () => Navigator.pop(ctx, minutosSeleccionados) : null,
            ),
            const SizedBox(height: 8),
            BotonSecundario(texto: 'Volver', color: ColoresApp.textoOscuro, colorBorde: ColoresApp.borde, onPressed: () => Navigator.pop(ctx, null)),
          ],
        ),
      ),
    );
    if (minutos == null || !mounted) return;
    setState(() => _pidiendoPlazoId = id);
    try {
      final resp = await TripService.requestMorePlazo(id, minutos);
      if (!mounted) return;
      _snack('Se le pidió al cliente $minutos min más. Esperando su respuesta.');
      setState(() {
        _reservas = _reservas.map((x) => idDeViaje(x) != id
            ? x
            : {...x, 'plazo': resp['plazo'] ?? {'minutos': minutos, 'estado': 'pendiente'}}).toList();
      });
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
    } catch (e) {
      if (mounted) _snack(mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _pidiendoPlazoId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget cuerpo;
    if (_loading) {
      cuerpo = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      cuerpo = ErrorCarga(titulo: 'No pudimos cargar tus reservas', detalle: _error, onReintentar: _cargar);
    } else if (_reservas.isEmpty) {
      cuerpo = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
        children: [
          Icon(Icons.event_available_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          const Text('No tienes reservas asignadas', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: Colors.black45)),
          const SizedBox(height: 6),
          const Text('Cuando un cliente acepte tu oferta a una reserva, aparecerá aquí.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.black38)),
        ],
      );
    } else {
      cuerpo = ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _reservas.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _tarjeta(_reservas[i]),
      );
    }
    return Scaffold(
      backgroundColor: ColoresApp.fondo,
      appBar: AppBar(title: const Text('Mis reservas')),
      body: RefreshIndicator(onRefresh: _cargar, child: cuerpo),
    );
  }

  Widget _tarjeta(Map<String, dynamic> r) {
    final id = idDeViaje(r);
    final cliente = r['cliente'] as Map<String, dynamic>?;
    final nombre = [cliente?['nombre'], cliente?['apellido']].whereType<String>().join(' ').trim();
    final precio = (r['precioFinal'] ?? r['precioEstimado']) as num?;
    final fecha = formatoFechaHoraReserva(r['fechaProgramada']?.toString(), r['horaProgramada']?.toString());
    final plazo = r['plazo'] as Map<String, dynamic>?;
    return TarjetaBlanca(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.event_rounded, size: 16, color: ColoresApp.azulOscuro),
          const SizedBox(width: 6),
          Expanded(child: Text(fecha ?? 'Fecha por confirmar', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ColoresApp.azulOscuro))),
          const ChipEstado.azul('Reserva'),
        ]),
        const SizedBox(height: 10),
        _parada(ColoresApp.verde, 'Recoge', _direccion(r['origen'])),
        const SizedBox(height: 6),
        _parada(ColoresApp.rojo, 'Entrega', _direccion(r['destino'])),
        const SizedBox(height: 10),
        Row(children: [
          const Icon(Icons.person_outline_rounded, size: 16, color: ColoresApp.textoSecundario),
          const SizedBox(width: 6),
          Expanded(child: Text(nombre.isEmpty ? 'Cliente' : nombre, style: const TextStyle(fontSize: 13, color: ColoresApp.textoSecundario))),
          Text(formatearPesos(precio), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ColoresApp.textoOscuro, fontFeatures: cifrasTabulares)),
        ]),
        const SizedBox(height: 6),
        const Text('Verás la ubicación y el teléfono 45 min antes de la recogida.', style: TextStyle(fontSize: 12, color: ColoresApp.textoSecundario)),
        const SizedBox(height: 12),
        if (plazo == null) ...[
          SizedBox(
            width: double.infinity,
            child: BotonSecundario(
              key: Key('reserva_plazo_$id'),
              texto: 'Pedir más tiempo',
              icono: Icons.schedule_rounded,
              alto: 44,
              cargando: _pidiendoPlazoId == id,
              onPressed: _pidiendoPlazoId == null ? () => _pedirPlazo(r) : null,
            ),
          ),
          const SizedBox(height: 8),
        ] else if (plazo['estado'] == 'pendiente') ...[
          const Align(alignment: Alignment.centerLeft, child: ChipEstado.naranja('Esperando respuesta del cliente')),
          const SizedBox(height: 8),
        ],
        Row(children: [
          Expanded(
            child: BotonPrincipal(
              key: Key('reserva_chat_$id'),
              texto: 'Chat',
              icono: Icons.chat_bubble_outline_rounded,
              alto: 44,
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TripChatScreen(trip: r))),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: BotonSecundario(
              key: Key('reserva_cancelar_$id'),
              texto: 'Cancelar',
              color: ColoresApp.rojo,
              alto: 44,
              cargando: _cancelandoId == id,
              onPressed: _cancelandoId == null ? () => _cancelar(r) : null,
            ),
          ),
        ]),
      ]),
    );
  }

  static String _direccion(dynamic d) => d is Map ? (d['direccion']?.toString() ?? '') : '';

  Widget _parada(Color color, String titulo, String texto) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(top: 5), child: Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle))),
        const SizedBox(width: 8),
        Expanded(child: Text('$titulo: ${texto.isEmpty ? '—' : texto}', style: const TextStyle(fontSize: 13, color: ColoresApp.textoOscuro), maxLines: 2, overflow: TextOverflow.ellipsis)),
      ]);
}
