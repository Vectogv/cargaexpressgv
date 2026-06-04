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
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _fetchConductores();
    _fetchVerificaciones();
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

  Future<void> _fetchConductores() async {
    setState(() => _loading = true);
    try {
      final res = await http.get(
        Uri.parse('${ApiClient.baseUrl}/api/admin/drivers'),
        headers: _authHeaders,
      );
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        setState(() {
          _conductores = List<Map<String, dynamic>>.from(data);
          _loading = false;
        });
      } else {
        _useFallback();
      }
    } catch (_) {
      _useFallback();
    }
  }

  Future<void> _fetchVerificaciones() async {
    try {
      final res = await http.get(
        Uri.parse('${ApiClient.baseUrl}/api/admin/verifications'),
        headers: _authHeaders,
      );
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        setState(() {
          _verificaciones = List<Map<String, dynamic>>.from(data);
        });
      } else {
        _useVerificacionesFallback();
      }
    } catch (_) {
      _useVerificacionesFallback();
    }
  }

  void _useFallback() {
    setState(() {
      _conductores = [
        {
          'id': 1,
          'nombre': 'Name',
          'apellido': 'Baman',
          'email': 'nbaman@gmail.com',
          'tipoVehiculo': 'Sedán',
          'placa': 'ABC123',
          'cedula': '1234567890',
          'estado': 'online',
          'verificado': false,
          'aprobado': false,
          'documentos': [null, null],
        },
        {
          'id': 2,
          'nombre': 'Neine',
          'apellido': 'Bernona',
          'email': 'nbernona@gmail.com',
          'tipoVehiculo': 'Camioneta',
          'placa': 'XYZ789',
          'cedula': '9876543210',
          'estado': 'online',
          'verificado': true,
          'aprobado': false,
          'documentos': [null, null],
        },
        {
          'id': 3,
          'nombre': 'Carlos',
          'apellido': 'Ruiz',
          'email': 'cruiz@gmail.com',
          'tipoVehiculo': 'Camión',
          'placa': 'DEF456',
          'cedula': '1122334455',
          'estado': 'offline',
          'verificado': false,
          'aprobado': true,
          'documentos': [null],
        },
      ];
      _loading = false;
    });
  }

  void _useVerificacionesFallback() {
    setState(() {
      _verificaciones = [
        {
          'conductorId': 4,
          'nombre': 'Maria',
          'apellido': 'Gomez',
          'email': 'mgomez@gmail.com',
          'tipoVehiculo': 'Sedán',
          'placa': 'LMN789',
          'cedula': '5566778899',
          'estado': 'online',
          'verificado': false,
          'aprobado': false,
          'documentos': [null, null],
        },
        {
          'conductorId': 5,
          'nombre': 'Pedro',
          'apellido': 'Lopez',
          'email': 'plopez@gmail.com',
          'tipoVehiculo': 'Camioneta',
          'placa': 'OPQ321',
          'cedula': '9988776655',
          'estado': 'offline',
          'verificado': false,
          'aprobado': false,
          'documentos': [null, null],
        },
      ];
    });
  }

  List<Map<String, dynamic>> get _filtrados {
    if (_filtro == 'todos') return _conductores;
    if (_filtro == 'online') {
      return _conductores
          .where((c) => c['estado'] == 'online')
          .toList();
    }
    if (_filtro == 'offline') {
      return _conductores
          .where((c) => c['estado'] == 'offline')
          .toList();
    }
    if (_filtro == 'verificado') {
      return _conductores
          .where((c) => c['verificado'] == true)
          .toList();
    }
    if (_filtro == 'pendiente') {
      return _conductores
          .where((c) => c['aprobado'] == false)
          .toList();
    }
    return _conductores;
  }

  Future<void> _accion(int id, String tipo) async {
    final endpoint = tipo == 'aprobar' ? 'approve' : 'reject';
    try {
      final res = await http.put(
        Uri.parse(
            '${ApiClient.baseUrl}/api/admin/drivers/$id/$endpoint'),
        headers: _authHeaders,
      );
      if (res.statusCode == 200) {
        setState(() {
          final idx = _conductores.indexWhere((c) => c['id'] == id);
          if (idx != -1) {
            _conductores[idx]['aprobado'] = tipo == 'aprobar';
          }
        });
        _showSnack(
            tipo == 'aprobar' ? 'Conductor aprobado' : 'Conductor rechazado');
      } else {
        _showSnack('Error al procesar');
      }
    } catch (_) {
      _showSnack('Error de conexión');
    }
  }

  Future<void> _accionVerificacion(int conductorId, String tipo) async {
    final endpoint = tipo == 'aprobar' ? 'approve' : 'reject';
    try {
      final res = await http.put(
        Uri.parse(
            '${ApiClient.baseUrl}/api/admin/verifications/$conductorId/$endpoint'),
        headers: _authHeaders,
      );
      if (res.statusCode == 200) {
        setState(() {
          _verificaciones.removeWhere((v) => v['conductorId'] == conductorId);
        });
        _showSnack(
            tipo == 'aprobar' ? 'Verificación aprobada' : 'Verificación rechazada');
        _fetchConductores();
      } else {
        _showSnack('Error al procesar');
      }
    } catch (_) {
      _showSnack('Error de conexión');
    }
  }

  void _mostrarDocumentos(Map<String, dynamic> v) {
    final docs = [
      if (v['fotoCedula'] != null) _DocItem('Cédula', v['fotoCedula']),
      if (v['fotoLicencia'] != null) _DocItem('Licencia', v['fotoLicencia']),
      if (v['fotoVehiculo'] != null) _DocItem('Vehículo', v['fotoVehiculo']),
    ];
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
              const Text('Documentos del Conductor',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('${v['nombre'] ?? ''} ${v['apellido'] ?? ''}',
                  style: const TextStyle(fontSize: 13, color: Colors.black45)),
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
                        errorBuilder: (_, __, ___) => Container(
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
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_filtrados.isEmpty) {
      return const Center(
        child: Text('Sin conductores',
            style: TextStyle(color: Colors.black45)));
    }
    return RefreshIndicator(
      onRefresh: _fetchConductores,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _filtrados.length,
        itemBuilder: (_, i) => _ConductorCard(
          conductor: _filtrados[i],
          onAprobar: () =>
              _accion(_filtrados[i]['id'], 'aprobar'),
          onRechazar: () =>
              _accion(_filtrados[i]['id'], 'rechazar'),
        ),
      ),
    );
  }

  Widget _buildVerificacionesList() {
    if (_verificaciones.isEmpty) {
      return const Center(
        child: Text('Sin verificaciones pendientes',
            style: TextStyle(color: Colors.black45)));
    }
    return RefreshIndicator(
      onRefresh: _fetchVerificaciones,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _verificaciones.length,
        itemBuilder: (_, i) {
          final v = _verificaciones[i];
          final condId = v['conductorId'] ?? v['id'];
          final usuario = v['usuario'] as Map<String, dynamic>?;
          return _ConductorCard(
            conductor: {
              ...v,
              'nombre': v['nombre'] ?? usuario?['nombre'] ?? '',
              'apellido': v['apellido'] ?? usuario?['apellido'] ?? '',
              'email': v['email'] ?? usuario?['email'] ?? '',
            },
            idKey: 'conductorId',
            onAprobar: () => _accionVerificacion(condId, 'aprobar'),
            onRechazar: () => _accionVerificacion(condId, 'rechazar'),
            onVerDocumentos: v['fotoCedula'] != null || v['fotoLicencia'] != null || v['fotoVehiculo'] != null
                ? () => _mostrarDocumentos(v)
                : null,
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
            icon: const Icon(Icons.chevron_left,
                color: Colors.black87, size: 26),
            onPressed: () => Navigator.maybePop(context),
          ),
          const Text(
            'GESTIÓN DE CONDUCTORES',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
              letterSpacing: 0.3,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black45, size: 20),
            onPressed: () {
              _fetchConductores();
              _fetchVerificaciones();
            },
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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
            ),
          ],
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(12),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.black54,
          labelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
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
      {'key': 'verificado', 'label': 'Verificado'},
      {'key': 'pendiente', 'label': 'Pendiente'},
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? Colors.black87 : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  if (!selected)
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                    ),
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
  final VoidCallback onAprobar;
  final VoidCallback onRechazar;
  final VoidCallback? onVerDocumentos;
  final String idKey;

  const _ConductorCard({
    required this.conductor,
    required this.onAprobar,
    required this.onRechazar,
    this.onVerDocumentos,
    this.idKey = 'id',
  });

  bool get _online => conductor['estado'] == 'online';
  bool get _verificado => conductor['verificado'] == true;
  bool get _aprobado => conductor['aprobado'] == true;

  String get _iniciales {
    final n = (conductor['nombre'] ?? '').toString();
    final a = (conductor['apellido'] ?? '').toString();
    return '${n.isNotEmpty ? n[0] : ''}${a.isNotEmpty ? a[0] : ''}'
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
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
                  color: _online
                      ? const Color(0xFF4CAF50)
                      : Colors.black38,
                ),
                const SizedBox(width: 8),
                if (_verificado)
                  _StatusPill(
                    label: 'Verificado',
                    color: const Color(0xFF1E88E5),
                    icon: Icons.verified_rounded,
                  ),
                if (_aprobado && !_verificado)
                  _StatusPill(
                    label: 'Aprobado',
                    color: const Color(0xFF43A047),
                    icon: Icons.check_circle_outline,
                  ),
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
                  child: Text(
                    _iniciales,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${conductor['nombre'] ?? ''} ${conductor['apellido'] ?? ''}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.directions_car_outlined,
                              size: 12, color: Colors.black38),
                          const SizedBox(width: 4),
                          Text(
                            '${conductor['tipoVehiculo'] ?? 'Vehículo'} · ${conductor['placa'] ?? ''}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black45),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Documentos',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.black45,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 8),
                _DocumentosRow(
                  count: (conductor['documentos'] as List?)?.length ?? 0,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                if (onVerDocumentos != null)
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
                      child: _ActionButton(
                        label: 'Aprobar',
                        filled: true,
                        onTap: onAprobar,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ActionButton(
                        label: 'Rechazar',
                        filled: false,
                        onTap: onRechazar,
                      ),
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

  const _StatusPill({
    required this.label,
    required this.color,
    this.icon,
  });

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
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentosRow extends StatelessWidget {
  final int count;
  const _DocumentosRow({required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ...List.generate(count, (i) => _DocThumbnail(index: i)),
        if (count < 3) const _AddDocButton(),
      ],
    );
  }
}

class _DocThumbnail extends StatelessWidget {
  final int index;
  const _DocThumbnail({required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 52,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            index == 0
                ? Icons.badge_outlined
                : Icons.directions_car_outlined,
            size: 20,
            color: const Color(0xFF90A4AE),
          ),
          const SizedBox(height: 2),
          Text(
            index == 0 ? 'Cédula' : 'Licencia',
            style: const TextStyle(
                fontSize: 8,
                color: Colors.black38,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _AddDocButton extends StatelessWidget {
  const _AddDocButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: const Color(0xFFBBDEFB), width: 1.5),
      ),
      child: const Icon(Icons.add, color: Color(0xFF90CAF9), size: 22),
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

  const _ActionButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: filled ? Colors.black87 : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: filled ? Colors.black87 : const Color(0xFFE0E0E0),
            width: 1.2,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: filled ? Colors.white : Colors.black54,
          ),
        ),
      ),
    );
  }
}
