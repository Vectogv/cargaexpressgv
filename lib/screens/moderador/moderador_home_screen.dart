import 'dart:async';

import 'package:flutter/material.dart';

import '../../contracts/trip_status.dart';
import '../../services/api/http_client.dart';
import '../../services/api/moderator_service.dart';
import '../../services/api_client.dart';
import '../../services/socket_service_client.dart';
import '../home_by_role.dart';
import '../user/auth_screen.dart';

const Color _primaryDark = Color(0xFF1A3C6E);
const Color _textDark = Color(0xFF1A1A2E);
const Color _textGrey = Color(0xFF757575);
const Color _bgLight = Color(0xFFF5F7FA);
const Color _accentRed = Color(0xFFE53935);
const Color _accentOrange = Color(0xFFFF9800);
const Color _accentGreen = Color(0xFF4CAF50);

/// Inicio del moderador de zona. Consume `/api/moderator/*`:
/// resumen de la zona, cierres pendientes de confirmación (resolver como
/// finalizado o disputa) y emergencias SOS (atender / resolver).
class ModeradorHomeScreen extends StatefulWidget {
  /// Inyectables para pruebas; por defecto usan los servicios reales.
  final ModeratorService service;
  final Stream<Map<String, dynamic>>? eventos;

  const ModeradorHomeScreen({
    super.key,
    this.service = const ModeratorService(),
    this.eventos,
  });

  @override
  State<ModeradorHomeScreen> createState() => _ModeradorHomeScreenState();
}

class _ModeradorHomeScreenState extends State<ModeradorHomeScreen> {
  Map<String, dynamic>? _dashboard;
  List<Map<String, dynamic>> _cierres = [];
  List<Map<String, dynamic>> _emergencias = [];
  bool _loading = true;
  String? _errorDashboard;
  String? _errorCierres;
  String? _errorEmergencias;
  final Set<String> _procesando = {};
  StreamSubscription<Map<String, dynamic>>? _eventosSub;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _cargarTodo();
    final eventos = widget.eventos ?? SocketServiceClient.instance.onModeratorEvent;
    // Cierres pendientes, cambios de viaje y emergencias de la zona llegan por
    // socket: refrescar (agrupando ráfagas) para no mostrar datos viejos.
    _eventosSub = eventos.listen((_) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 400), _cargarTodo);
    });
  }

  @override
  void dispose() {
    _eventosSub?.cancel();
    _debounce?.cancel();
    super.dispose();
  }

  String _errorText(Object e) =>
      e is ApiException ? e.message : e.toString().replaceFirst('Exception: ', '');

  Future<void> _cargarTodo() async {
    await Future.wait([_cargarDashboard(), _cargarCierres(), _cargarEmergencias()]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _cargarDashboard() async {
    try {
      final data = await widget.service.getDashboard();
      if (!mounted) return;
      setState(() {
        _dashboard = data;
        _errorDashboard = null;
      });
    } catch (e) {
      if (mounted) setState(() => _errorDashboard = _errorText(e));
    }
  }

  Future<void> _cargarCierres() async {
    try {
      final list = await widget.service.getPendingCloses();
      if (!mounted) return;
      setState(() {
        _cierres = list;
        _errorCierres = null;
      });
    } catch (e) {
      if (mounted) setState(() => _errorCierres = _errorText(e));
    }
  }

  Future<void> _cargarEmergencias() async {
    try {
      final list = await widget.service.getEmergencies();
      if (!mounted) return;
      setState(() {
        _emergencias = list;
        _errorEmergencias = null;
      });
    } catch (e) {
      if (mounted) setState(() => _errorEmergencias = _errorText(e));
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red.shade700 : null,
      duration: Duration(seconds: error ? 5 : 3),
    ));
  }

  Future<void> _logout() async {
    await ApiClient.instance.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (_) => false,
    );
  }

  /// El moderador es además cliente o conductor: permitir usar esa cuenta.
  HomeDestino get _cuentaPropia =>
      homeDestinoFor(rol: ApiClient.instance.rol, esModerador: false);

  // ── Acciones ────────────────────────────────────────────────────────────

  Future<void> _resolverCierre(Map<String, dynamic> viaje) async {
    final id = viaje['id']?.toString();
    if (id == null) return;
    final result = await showDialog<_Resolucion>(
      context: context,
      builder: (_) => _ResolverCierreDialog(viajeId: id),
    );
    if (result == null || !mounted) return;
    setState(() => _procesando.add('viaje:$id'));
    try {
      await widget.service.resolvePendingClose(
        id,
        resolucion: result.resolucion,
        nota: result.nota,
      );
      _snack(result.resolucion == 'finalizar'
          ? 'Viaje #$id finalizado'
          : 'Viaje #$id enviado a disputa');
      await _cargarTodo();
    } catch (e) {
      // 409 CONFIRMACION_EN_PLAZO, 422, 403...: mostrar el mensaje del backend.
      _snack(_errorText(e), error: true);
      await _cargarCierres();
    } finally {
      if (mounted) setState(() => _procesando.remove('viaje:$id'));
    }
  }

  Future<void> _accionEmergencia(Map<String, dynamic> alerta, {required bool resolver}) async {
    final id = alerta['id']?.toString();
    if (id == null) return;
    String? observacion;
    if (resolver) {
      final ctrl = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Resolver emergencia'),
          content: TextField(
            controller: ctrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Observación (opcional)',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Resolver')),
          ],
        ),
      );
      observacion = ctrl.text;
      ctrl.dispose();
      if (ok != true || !mounted) return;
    }
    setState(() => _procesando.add('sos:$id'));
    try {
      if (resolver) {
        await widget.service.resolveEmergency(id, observacion: observacion);
        _snack('Emergencia resuelta');
      } else {
        await widget.service.acknowledgeEmergency(id);
        _snack('Emergencia marcada como atendida');
      }
      await _cargarEmergencias();
    } catch (e) {
      _snack(_errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _procesando.remove('sos:$id'));
    }
  }

  // ── UI ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final zona = (_dashboard?['ciudad'] ?? ApiClient.instance.zonaModerador)?.toString();
    final sosPendientes = _emergencias.where((e) => e['estado'] == 'pendiente').length;
    final cuentaPropia = _cuentaPropia;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: _bgLight,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: _textDark,
          elevation: 0.5,
          automaticallyImplyLeading: false,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Moderación', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20)),
              if (zona != null && zona.isNotEmpty)
                Text('Zona: $zona', style: const TextStyle(fontSize: 12, color: _textGrey)),
            ],
          ),
          actions: [
            if (cuentaPropia != HomeDestino.ninguno)
              IconButton(
                tooltip: cuentaPropia == HomeDestino.conductor
                    ? 'Ir a mi cuenta de conductor'
                    : 'Ir a mi cuenta de cliente',
                icon: const Icon(Icons.swap_horiz),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => homeScreenFor(cuentaPropia)),
                ),
              ),
            IconButton(
              tooltip: 'Actualizar',
              icon: const Icon(Icons.refresh),
              onPressed: _cargarTodo,
            ),
            IconButton(
              tooltip: 'Cerrar sesión',
              icon: const Icon(Icons.logout),
              onPressed: _logout,
            ),
          ],
          bottom: TabBar(
            labelColor: _primaryDark,
            unselectedLabelColor: _textGrey,
            indicatorColor: _primaryDark,
            tabs: [
              const Tab(text: 'Resumen'),
              Tab(text: _cierres.isEmpty ? 'Cierres' : 'Cierres (${_cierres.length})'),
              Tab(text: sosPendientes == 0 ? 'Emergencias' : 'Emergencias ($sosPendientes)'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildResumen(),
                  _buildCierres(),
                  _buildEmergencias(),
                ],
              ),
      ),
    );
  }

  Widget _buildError(String msg, Future<void> Function() retry) {
    return _Refreshable(
      onRefresh: retry,
      child: Column(
        children: [
          const Icon(Icons.error_outline, size: 48, color: _accentRed),
          const SizedBox(height: 12),
          Text(msg, textAlign: TextAlign.center, style: const TextStyle(color: _textDark)),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: retry, child: const Text('Reintentar')),
        ],
      ),
    );
  }

  Widget _buildEmpty(IconData icon, String msg, Future<void> Function() refresh) {
    return _Refreshable(
      onRefresh: refresh,
      child: Column(
        children: [
          Icon(icon, size: 48, color: _textGrey),
          const SizedBox(height: 12),
          Text(msg, textAlign: TextAlign.center, style: const TextStyle(color: _textGrey)),
        ],
      ),
    );
  }

  Widget _buildResumen() {
    if (_errorDashboard != null && _dashboard == null) {
      return _buildError(_errorDashboard!, _cargarDashboard);
    }
    final d = _dashboard ?? const {};
    int n(String k) => (d[k] as num?)?.toInt() ?? 0;
    final items = <(String, int, IconData, Color)>[
      ('Cierres por resolver', _cierres.length, Icons.fact_check_outlined, _accentOrange),
      ('Emergencias pendientes', _emergencias.where((e) => e['estado'] == 'pendiente').length,
          Icons.crisis_alert_rounded, _accentRed),
      ('Conductores', n('totalDrivers'), Icons.local_shipping_outlined, _primaryDark),
      ('En línea', n('onlineDrivers'), Icons.wifi_tethering, _accentGreen),
      ('Inactivos (7 días)', n('inactiveDrivers'), Icons.bedtime_outlined, _textGrey),
      ('Comunicados', n('totalComunicados'), Icons.campaign_outlined, _primaryDark),
    ];
    return RefreshIndicator(
      onRefresh: _cargarTodo,
      child: GridView.count(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.5,
        children: [
          for (final (label, value, icon, color) in items)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, color: color),
                  Text('$value', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _textDark)),
                  Text(label, style: const TextStyle(fontSize: 12, color: _textGrey)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCierres() {
    if (_errorCierres != null && _cierres.isEmpty) {
      return _buildError(_errorCierres!, _cargarCierres);
    }
    if (_cierres.isEmpty) {
      return _buildEmpty(Icons.check_circle_outline,
          'No hay viajes esperando confirmación del cliente en tu zona.', _cargarCierres);
    }
    return RefreshIndicator(
      onRefresh: _cargarCierres,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _cierres.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final v = _cierres[i];
          final id = v['id']?.toString() ?? '';
          final cliente = v['cliente'] as Map?;
          final conductor = v['conductor'] as Map?;
          final busy = _procesando.contains('viaje:$id');
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Viaje #$id', style: const TextStyle(fontWeight: FontWeight.w700, color: _textDark)),
                    const Spacer(),
                    Text(
                      TripStatus.label(v['estado'] as String?),
                      style: const TextStyle(fontSize: 12, color: _accentOrange, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (v['origenDireccion'] != null)
                  Text('Origen: ${v['origenDireccion']}', style: const TextStyle(fontSize: 12, color: _textGrey)),
                if (v['destinoDireccion'] != null)
                  Text('Destino: ${v['destinoDireccion']}', style: const TextStyle(fontSize: 12, color: _textGrey)),
                if (cliente != null)
                  Text('Cliente: ${cliente['nombre'] ?? ''} ${cliente['telefono'] ?? ''}',
                      style: const TextStyle(fontSize: 12, color: _textGrey)),
                if (conductor != null)
                  Text('Conductor: ${conductor['nombre'] ?? ''} · ${conductor['placa'] ?? ''}',
                      style: const TextStyle(fontSize: 12, color: _textGrey)),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: busy ? null : () => _resolverCierre(v),
                    icon: busy
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.gavel_rounded, size: 18),
                    label: const Text('Resolver cierre'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryDark,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmergencias() {
    if (_errorEmergencias != null && _emergencias.isEmpty) {
      return _buildError(_errorEmergencias!, _cargarEmergencias);
    }
    if (_emergencias.isEmpty) {
      return _buildEmpty(Icons.shield_outlined, 'No hay emergencias registradas en tu zona.', _cargarEmergencias);
    }
    return RefreshIndicator(
      onRefresh: _cargarEmergencias,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _emergencias.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final a = _emergencias[i];
          final id = a['id']?.toString() ?? '';
          final estado = a['estado']?.toString() ?? 'pendiente';
          final usuario = a['usuario'] as Map?;
          final viaje = a['viaje'] as Map?;
          final busy = _procesando.contains('sos:$id');
          final color = estado == 'pendiente'
              ? _accentRed
              : estado == 'atendida'
                  ? _accentOrange
                  : _accentGreen;
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border(left: BorderSide(color: color, width: 4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.sos_rounded, color: color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        usuario?['nombre']?.toString() ?? 'Alerta #$id',
                        style: const TextStyle(fontWeight: FontWeight.w700, color: _textDark),
                      ),
                    ),
                    Text(a['estadoLabel']?.toString() ?? estado,
                        style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
                  ],
                ),
                if (a['motivo'] != null) ...[
                  const SizedBox(height: 6),
                  Text('${a['motivo']}', style: const TextStyle(fontSize: 13, color: _textDark)),
                ],
                if (usuario?['telefono'] != null)
                  Text('Tel: ${usuario!['telefono']}', style: const TextStyle(fontSize: 12, color: _textGrey)),
                if (viaje != null)
                  Text('Viaje #${viaje['id']} · ${viaje['estadoLabel'] ?? viaje['estado'] ?? ''}',
                      style: const TextStyle(fontSize: 12, color: _textGrey)),
                if (estado != 'resuelta') ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (estado == 'pendiente')
                        Expanded(
                          child: OutlinedButton(
                            onPressed: busy ? null : () => _accionEmergencia(a, resolver: false),
                            child: const Text('Atender'),
                          ),
                        ),
                      if (estado == 'pendiente') const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: busy ? null : () => _accionEmergencia(a, resolver: true),
                          style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
                          child: const Text('Resolver'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Contenido desplazable (para permitir "tirar para refrescar") centrado.
class _Refreshable extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final Widget child;
  const _Refreshable({required this.onRefresh, required this.child});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(32, 80, 32, 32),
        children: [child],
      ),
    );
  }
}

class _Resolucion {
  final String resolucion;
  final String nota;
  const _Resolucion(this.resolucion, this.nota);
}

/// Diálogo para resolver un cierre pendiente: finalizar o enviar a disputa,
/// con una nota obligatoria (el backend exige al menos 10 caracteres).
class _ResolverCierreDialog extends StatefulWidget {
  final String viajeId;
  const _ResolverCierreDialog({required this.viajeId});

  @override
  State<_ResolverCierreDialog> createState() => _ResolverCierreDialogState();
}

class _ResolverCierreDialogState extends State<_ResolverCierreDialog> {
  String _resolucion = 'finalizar';
  final _notaCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _notaCtrl.dispose();
    super.dispose();
  }

  void _confirmar() {
    final nota = _notaCtrl.text.trim();
    if (nota.length < 10) {
      setState(() => _error = 'La nota debe tener al menos 10 caracteres');
      return;
    }
    Navigator.pop(context, _Resolucion(_resolucion, nota));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Resolver cierre · Viaje #${widget.viajeId}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RadioGroup<String>(
              groupValue: _resolucion,
              onChanged: (v) => setState(() => _resolucion = v ?? _resolucion),
              child: const Column(
                children: [
                  RadioListTile<String>(
                    value: 'finalizar',
                    contentPadding: EdgeInsets.zero,
                    title: Text('Finalizar viaje'),
                    subtitle: Text('La entrega se considera correcta'),
                  ),
                  RadioListTile<String>(
                    value: 'disputa',
                    contentPadding: EdgeInsets.zero,
                    title: Text('Enviar a disputa'),
                    subtitle: Text('Hay indicios de un problema en la entrega'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notaCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Nota de la resolución',
                hintText: 'Explica el motivo (mínimo 10 caracteres)',
                errorText: _error,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(onPressed: _confirmar, child: const Text('Confirmar')),
      ],
    );
  }
}
