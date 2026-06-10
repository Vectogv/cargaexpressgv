import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../services/api_client.dart';

class GestionConductoresScreen extends StatefulWidget {
  const GestionConductoresScreen({super.key});

  @override
  State<GestionConductoresScreen> createState() =>
      _GestionConductoresScreenState();
}

class _GestionConductoresScreenState extends State<GestionConductoresScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  List<Map<String, dynamic>> _conductores = [];
  List<Map<String, dynamic>> _verificaciones = [];
  String _filtro = 'todos';
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    _fetchAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Map<String, String> get _authHeaders => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${ApiClient.instance.token}',
  };

  Future<void> _fetchAll() async {
    setState(() => _loading = true);
    await Future.wait([_fetchConductores(), _fetchVerificaciones()]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _fetchConductores() async {
    try {
      final res = await http.get(
        Uri.parse('${ApiClient.baseUrl}/api/admin/drivers'),
        headers: _authHeaders,
      );
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        setState(() => _conductores = List<Map<String, dynamic>>.from(data));
      }
    } catch (_) {}
  }

  Future<void> _fetchVerificaciones() async {
    try {
      final res = await http.get(
        Uri.parse('${ApiClient.baseUrl}/api/admin/verifications'),
        headers: _authHeaders,
      );
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        setState(() => _verificaciones = List<Map<String, dynamic>>.from(data));
      }
    } catch (_) {}
  }

  List<Map<String, dynamic>> get _filtrados {
    if (_filtro == 'todos') return _conductores;
    if (_filtro == 'online') {
      return _conductores.where((c) => c['online'] == true).toList();
    }
    if (_filtro == 'offline') {
      return _conductores.where((c) => c['online'] == false).toList();
    }
    return _conductores;
  }

  Future<void> _aprobarVerificacion(dynamic conductorId) async {
    try {
      final res = await http.put(
        Uri.parse('${ApiClient.baseUrl}/api/admin/verifications/$conductorId/approve'),
        headers: _authHeaders,
      );
      if (res.statusCode == 200) {
        _verificaciones.removeWhere((v) => v['id'] == conductorId);
        _showSnack('Conductor verificado correctamente');
        _fetchConductores();
        if (mounted) setState(() {});
      } else {
        _showSnack('Error al aprobar');
      }
    } catch (_) {
      _showSnack('Error de conexión');
    }
  }

  Future<void> _rechazarVerificacion(dynamic conductorId) async {
    final textCtrl = TextEditingController();
    final nota = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Motivo del rechazo'),
        content: TextField(
          controller: textCtrl,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Indica el motivo del rechazo...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, textCtrl.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Rechazar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (nota == null || nota.isEmpty) return;

    try {
      final res = await http.put(
        Uri.parse('${ApiClient.baseUrl}/api/admin/verifications/$conductorId/reject'),
        headers: _authHeaders,
        body: jsonEncode({'nota': nota}),
      );
      if (res.statusCode == 200) {
        _verificaciones.removeWhere((v) => v['id'] == conductorId);
        _showSnack('Conductor rechazado');
        _fetchConductores();
        if (mounted) setState(() {});
      } else {
        _showSnack('Error al rechazar');
      }
    } catch (_) {
      _showSnack('Error de conexión');
    }
  }

  void _mostrarDocumentos(Map<String, dynamic> v) {
    final usuario = v['usuario'] as Map<String, dynamic>?;
    final docs = <_DocItem>[];
    if (v['fotoCedula'] != null) docs.add(_DocItem('Cédula', v['fotoCedula']));
    if (v['fotoLicencia'] != null) docs.add(_DocItem('Licencia', v['fotoLicencia']));
    if (v['fotoVehiculo'] != null) docs.add(_DocItem('Vehículo', v['fotoVehiculo']));
    if (docs.isEmpty) return;

    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Documentos',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                '${usuario?['nombre'] ?? v['nombre'] ?? ''} ${usuario?['apellido'] ?? v['apellido'] ?? ''}',
                style: const TextStyle(fontSize: 13, color: Colors.black45),
              ),
              const SizedBox(height: 16),
              ...docs.map((doc) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(doc.label,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54)),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        '${ApiClient.baseUrl}${doc.url}',
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          height: 200,
                          color: const Color(0xFFF2F2F7),
                          child: const Center(child: Text('Imagen no disponible', style: TextStyle(color: Colors.black45))),
                        ),
                        loadingBuilder: (_, child, progress) => progress == null ? child : const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cerrar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F7),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            _buildTabBar(),
            if (_tabController.index == 0) _buildFiltros(),
            Expanded(
              child: _tabController.index == 0
                  ? _buildConductoresList()
                  : _buildVerificacionesList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConductoresList() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_filtrados.isEmpty) {
      return const Center(child: Text('Sin conductores', style: TextStyle(color: Colors.black45)));
    }
    return RefreshIndicator(
      onRefresh: _fetchConductores,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _filtrados.length,
        itemBuilder: (_, i) => _ConductorCard(conductor: _filtrados[i]),
      ),
    );
  }

  Widget _buildVerificacionesList() {
    if (_verificaciones.isEmpty) {
      return const Center(
        child: Text('Sin verificaciones pendientes', style: TextStyle(color: Colors.black45)),
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchVerificaciones,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _verificaciones.length,
        itemBuilder: (_, i) {
          final v = _verificaciones[i];
          final condId = v['id'];
          final usuario = v['usuario'] as Map<String, dynamic>?;
          return _VerificacionCard(
            nombre: usuario?['nombre'] as String? ?? '',
            apellido: usuario?['apellido'] as String? ?? '',
            email: usuario?['email'] as String? ?? '',
            tipoVehiculo: v['tipoVehiculo'] as String? ?? '',
            placa: v['placa'] as String? ?? '',
            tieneDocs: v['fotoCedula'] != null || v['fotoLicencia'] != null || v['fotoVehiculo'] != null,
            onVerDocumentos: () => _mostrarDocumentos(v),
            onAprobar: () => _aprobarVerificacion(condId),
            onRechazar: () => _rechazarVerificacion(condId),
          );
        },
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      color: const Color(0xFFF2F3F7),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.black87, size: 26),
            onPressed: () => Navigator.maybePop(context),
          ),
          const Text(
            'GESTIÓN DE CONDUCTORES',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87, letterSpacing: 0.3),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black45, size: 20),
            onPressed: _fetchAll,
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: const Color(0xFFF2F3F7),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(12)),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.black54,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          tabs: const [
            Tab(text: 'Conductores'),
            Tab(text: 'Verificaciones'),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltros() {
    final filtros = [
      {'key': 'todos', 'label': 'Todos'},
      {'key': 'online', 'label': 'Online'},
      {'key': 'offline', 'label': 'Offline'},
    ];
    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filtros.length,
        itemBuilder: (_, i) {
          final selected = _filtro == filtros[i]['key'];
          return GestureDetector(
            onTap: () => setState(() => _filtro = filtros[i]['key']!),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? Colors.black87 : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  if (!selected)
                    BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4),
                ],
              ),
              child: Text(
                filtros[i]['label']!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : Colors.black54,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ConductorCard extends StatelessWidget {
  final Map<String, dynamic> conductor;

  const _ConductorCard({required this.conductor});

  bool get _online => conductor['online'] == true;

  String get _estadoVerif => conductor['estadoVerificacion'] as String? ?? 'pendiente';

  int get _docsCount {
    int c = 0;
    if (conductor['fotoCedula'] != null) c++;
    if (conductor['fotoLicencia'] != null) c++;
    if (conductor['fotoVehiculo'] != null) c++;
    return c;
  }

  Widget _buildVerifPill() {
    switch (_estadoVerif) {
      case 'aprobado':
        return _StatusPill(label: 'Aprobado', color: const Color(0xFF4CAF50), icon: Icons.check_circle);
      case 'rechazado':
        return _StatusPill(label: 'Rechazado', color: const Color(0xFFE53935), icon: Icons.cancel);
      default:
        return _StatusPill(label: 'Pendiente', color: const Color(0xFFFF9800), icon: Icons.schedule);
    }
  }

  String get _iniciales {
    final usuario = conductor['usuario'] as Map<String, dynamic>?;
    final n = (usuario?['nombre'] ?? '').toString();
    final a = (usuario?['apellido'] ?? '').toString();
    return '${n.isNotEmpty ? n[0] : ''}${a.isNotEmpty ? a[0] : ''}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final usuario = conductor['usuario'] as Map<String, dynamic>?;
    final nombre = '${usuario?['nombre'] ?? ''} ${usuario?['apellido'] ?? ''}'.trim();
    final email = usuario?['email'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                _StatusPill(
                  label: _online ? 'Online' : 'Offline',
                  color: _online ? const Color(0xFF4CAF50) : Colors.black38,
                ),
                const SizedBox(width: 8),
                _buildVerifPill(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFFE0E0E0),
                  child: Text(_iniciales, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nombre.isNotEmpty ? nombre : 'Sin nombre', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black87)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.directions_car_outlined, size: 12, color: Colors.black38),
                          const SizedBox(width: 4),
                          Text(
                            '${conductor['tipoVehiculo'] ?? 'Vehículo'} · ${conductor['placa'] ?? ''}',
                            style: const TextStyle(fontSize: 12, color: Colors.black45),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 16, color: Color(0xFFFFC107)),
                        const SizedBox(width: 2),
                        Text('${conductor['calificacion'] ?? '0.0'}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    Text('${conductor['totalViajes'] ?? 0} viajes', style: const TextStyle(fontSize: 11, color: Colors.black45)),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Row(
              children: [
                Text(email, style: const TextStyle(fontSize: 12, color: Colors.black45)),
                const Spacer(),
                Text('$_docsCount/3 docs', style: TextStyle(fontSize: 11, color: _docsCount == 3 ? const Color(0xFF4CAF50) : const Color(0xFFFF9800), fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }
}

class _VerificacionCard extends StatelessWidget {
  final String nombre;
  final String apellido;
  final String email;
  final String tipoVehiculo;
  final String placa;
  final bool tieneDocs;
  final VoidCallback onVerDocumentos;
  final VoidCallback onAprobar;
  final VoidCallback onRechazar;

  const _VerificacionCard({
    required this.nombre,
    required this.apellido,
    required this.email,
    required this.tipoVehiculo,
    required this.placa,
    required this.tieneDocs,
    required this.onVerDocumentos,
    required this.onAprobar,
    required this.onRechazar,
  });

  String get _iniciales {
    return '${nombre.isNotEmpty ? nombre[0] : ''}${apellido.isNotEmpty ? apellido[0] : ''}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: _StatusPill(
              label: 'Pendiente',
              color: const Color(0xFFFF9800),
              icon: Icons.schedule,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFFE0E0E0),
                  child: Text(_iniciales, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$nombre $apellido', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black87)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.directions_car_outlined, size: 12, color: Colors.black38),
                          const SizedBox(width: 4),
                          Text('$tipoVehiculo · $placa', style: const TextStyle(fontSize: 12, color: Colors.black45)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(email, style: const TextStyle(fontSize: 12, color: Colors.black45)),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                if (tieneDocs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: onVerDocumentos,
                        icon: const Icon(Icons.visibility_rounded, size: 16),
                        label: const Text('Ver Documentos'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1565C0),
                          side: const BorderSide(color: Color(0xFF1565C0)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(label: 'Aprobar', filled: true, onTap: onAprobar),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ActionButton(label: 'Rechazar', filled: false, onTap: onRechazar),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const _StatusPill({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 3),
          ],
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

class _DocItem {
  final String label;
  final String url;
  const _DocItem(this.label, this.url);
}

class _ActionButton extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _ActionButton({required this.label, required this.filled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: filled ? Colors.black87 : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: filled ? Colors.black87 : const Color(0xFFE0E0E0), width: 1.2),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: filled ? Colors.white : Colors.black54),
        ),
      ),
    );
  }
}
