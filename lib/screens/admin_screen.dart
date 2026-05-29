import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/admin_service.dart';
import '../services/api_client.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Panel Admin',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.person, color: Colors.white.withValues(alpha: 0.7)),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _AdminProfileScreen())),
          ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: const [
          _DashboardTab(),
          _UsersTab(),
          _DriversTab(),
          _TripsTab(),
          _EarningsTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF0D0D0D),
        selectedItemColor: const Color(0xFF1A8CFF),
        unselectedItemColor: Colors.white38,
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Usuarios'),
          BottomNavigationBarItem(icon: Icon(Icons.local_shipping), label: 'Conductores'),
          BottomNavigationBarItem(icon: Icon(Icons.route), label: 'Viajes'),
          BottomNavigationBarItem(icon: Icon(Icons.monetization_on), label: 'Ganancias'),
        ],
      ),
    );
  }
}

// ─── ADMIN PROFILE SCREEN ──────────────────────────────────────────────

class _AdminProfileScreen extends StatefulWidget {
  const _AdminProfileScreen();
  @override
  State<_AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<_AdminProfileScreen> {
  final _service = AdminService();
  final _nombreCtrl = TextEditingController();
  final _apellidoCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _avatar;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _emailCtrl.dispose();
    _telefonoCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final p = await _service.getProfile();
      if (mounted) setState(() {
        _nombreCtrl.text = p['nombre'] ?? '';
        _apellidoCtrl.text = p['apellido'] ?? '';
        _emailCtrl.text = p['email'] ?? '';
        _telefonoCtrl.text = p['telefono'] ?? '';
        _avatar = p['avatar'];
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    try {
      final res = await _service.uploadProfileAvatar(bytes, file.name);
      if (mounted) setState(() => _avatar = res['avatar']);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _service.updateProfile({
        'nombre': _nombreCtrl.text,
        'apellido': _apellidoCtrl.text,
        'email': _emailCtrl.text,
        'telefono': _telefonoCtrl.text,
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil actualizado'), backgroundColor: Color(0xFF1A8CFF)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: const Text('Mi Perfil', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1A8CFF)))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                GestureDetector(
                  onTap: _pickAvatar,
                  child: Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 48,
                          backgroundColor: const Color(0xFF1A8CFF).withValues(alpha: 0.15),
                          backgroundImage: _avatar != null ? NetworkImage('${ApiClient.defaultBaseUrl.replaceAll('/api', '')}$_avatar') : null,
                          child: _avatar == null
                              ? const Icon(Icons.admin_panel_settings, color: Color(0xFF1A8CFF), size: 40)
                              : null,
                        ),
                        Positioned(
                          bottom: 0, right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A8CFF), shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                _field('Nombre', _nombreCtrl),
                const SizedBox(height: 16),
                _field('Apellido', _apellidoCtrl),
                const SizedBox(height: 16),
                _field('Email', _emailCtrl, keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 16),
                _field('Teléfono', _telefonoCtrl, keyboardType: TextInputType.phone),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A8CFF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _saving
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Guardar cambios', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.06),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
}

// ─── DASHBOARD ─────────────────────────────────────────────────────────

class _DashboardTab extends StatefulWidget {
  const _DashboardTab();
  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  final _service = AdminService();
  AdminDashboard? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _service.getDashboard();
      if (mounted) setState(() { _data = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: Color(0xFF1A8CFF)));
    if (_data == null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.error_outline, size: 48, color: Colors.white.withValues(alpha: 0.2)),
        const SizedBox(height: 16),
        Text('Error al cargar', style: TextStyle(color: Colors.white.withValues(alpha: 0.4))),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: () { setState(() => _loading = true); _load(); }, child: const Text('Reintentar')),
      ]));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        _header(),
        const SizedBox(height: 20),
        _earningsCard(),
        const SizedBox(height: 16),
        _statsGrid(),
        const SizedBox(height: 16),
        _summaryCard(),
      ]),
    );
  }

  Widget _header() => Column(children: [
    Container(width: 64, height: 64, decoration: BoxDecoration(
      color: const Color(0xFF1A8CFF).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(18)),
      child: const Icon(Icons.admin_panel_settings, color: Color(0xFF1A8CFF), size: 32)),
    const SizedBox(height: 12),
    const Text('Dashboard', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
    Text('Panel de administración', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13)),
  ]);

  Widget _earningsCard() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [const Color(0xFF1A8CFF).withValues(alpha: 0.2), const Color(0xFF0A0A0A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFF1A8CFF).withValues(alpha: 0.2))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(Icons.monetization_on, size: 18, color: Colors.greenAccent), const SizedBox(width: 8),
        const Text('GANANCIAS', style: TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5))]),
      const SizedBox(height: 20),
      Row(children: [
        _earningItem('Hoy', '\$${_data!.todayEarnings.toStringAsFixed(2)}'),
        _earningItem('Este mes', '\$${_data!.monthEarnings.toStringAsFixed(2)}'),
        _earningItem('Total', '\$${_data!.totalEarnings.toStringAsFixed(2)}'),
      ]),
    ]),
  );

  Widget _earningItem(String label, String value) => Expanded(child: Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
  ]));

  Widget _statsGrid() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: 0.06))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(Icons.bar_chart_rounded, size: 16, color: const Color(0xFF1A8CFF)), const SizedBox(width: 8),
        const Text('ESTADÍSTICAS DEL DÍA', style: TextStyle(color: Color(0xFF1A8CFF), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5))]),
      const SizedBox(height: 20),
      Row(children: [Expanded(child: _StatBox(icon: Icons.local_shipping, label: 'Envíos hoy', value: '${_data!.todayShipments}', color: const Color(0xFF1A8CFF))), const SizedBox(width: 12),
        Expanded(child: _StatBox(icon: Icons.people, label: 'Conductores', value: '${_data!.totalDrivers}', color: Colors.greenAccent))]),
      const SizedBox(height: 12),
      Row(children: [Expanded(child: _StatBox(icon: Icons.person, label: 'Usuarios totales', value: '${_data!.totalUsers}', color: Colors.orangeAccent)), const SizedBox(width: 12),
        Expanded(child: _StatBox(icon: Icons.directions_car, label: 'Vehículos activos', value: '${_data!.activeVehicles}', color: Colors.purpleAccent))]),
    ]),
  );

  Widget _summaryCard() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: 0.06))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(Icons.info_outline, size: 16, color: Colors.white.withValues(alpha: 0.5)), const SizedBox(width: 8),
        Text('RESUMEN GENERAL', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5))]),
      const SizedBox(height: 16),
      _infoRow(Icons.people_outline, 'Usuarios registrados', '${_data!.totalUsers}'),
      _infoRow(Icons.local_shipping, 'Conductores registrados', '${_data!.totalDrivers}'),
      _infoRow(Icons.directions_car, 'Vehículos activos ahora', '${_data!.activeVehicles}'),
      _infoRow(Icons.check_circle, 'Envíos completados hoy', '${_data!.todayShipments}'),
    ]),
  );

  Widget _infoRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.35)),
      const SizedBox(width: 12),
      Expanded(child: Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14))),
      Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
    ]),
  );
}

class _StatBox extends StatelessWidget {
  final IconData icon; final String label; final String value; final Color color;
  const _StatBox({required this.icon, required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withValues(alpha: 0.15))),
    child: Column(children: [
      Icon(icon, size: 24, color: color),
      const SizedBox(height: 8),
      Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
      Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11, fontWeight: FontWeight.w500)),
    ]),
  );
}

// ─── EDIT USER DIALOG ──────────────────────────────────────────────────

class _EditUserDialog extends StatefulWidget {
  final AdminUser user;
  const _EditUserDialog({required this.user});
  @override
  State<_EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<_EditUserDialog> {
  late TextEditingController _nombreCtrl;
  late TextEditingController _apellidoCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _telefonoCtrl;
  late TextEditingController _edadCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.user.nombre);
    _apellidoCtrl = TextEditingController(text: widget.user.apellido);
    _emailCtrl = TextEditingController(text: widget.user.email);
    _telefonoCtrl = TextEditingController(text: widget.user.telefono);
    _edadCtrl = TextEditingController(text: widget.user.edad?.toString());
  }

  @override
  void dispose() {
    _nombreCtrl.dispose(); _apellidoCtrl.dispose(); _emailCtrl.dispose();
    _telefonoCtrl.dispose(); _edadCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await AdminService().updateUser(widget.user.id, {
        'nombre': _nombreCtrl.text,
        'apellido': _apellidoCtrl.text,
        'email': _emailCtrl.text,
        'telefono': _telefonoCtrl.text,
        'edad': _edadCtrl.text.isNotEmpty ? int.tryParse(_edadCtrl.text) : null,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      title: const Text('Editar usuario', style: TextStyle(color: Colors.white, fontSize: 18)),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _field('Nombre', _nombreCtrl),
          const SizedBox(height: 12),
          _field('Apellido', _apellidoCtrl),
          const SizedBox(height: 12),
          _field('Email', _emailCtrl, keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 12),
          _field('Teléfono', _telefonoCtrl, keyboardType: TextInputType.phone),
          const SizedBox(height: 12),
          _field('Edad', _edadCtrl, keyboardType: TextInputType.number),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.white54))),
        TextButton(onPressed: _saving ? null : _save, child: _saving
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : const Text('Guardar', style: TextStyle(color: Color(0xFF1A8CFF)))),
      ],
    );
  }

  Widget _field(String label, TextEditingController ctrl, {TextInputType? keyboardType}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      TextField(
        controller: ctrl, keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          filled: true, fillColor: Colors.white.withValues(alpha: 0.06),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    ],
  );
}

// ─── USERS TAB ─────────────────────────────────────────────────────────

class _UsersTab extends StatefulWidget {
  const _UsersTab();
  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  final _service = AdminService();
  List<AdminUser>? _users;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final users = await _service.getUsers();
      if (mounted) setState(() { _users = users; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Color _roleColor(String? rol) {
    switch (rol) {
      case 'admin': return Colors.redAccent;
      case 'conductor': return const Color(0xFF1A8CFF);
      case 'cliente': return Colors.greenAccent;
      default: return Colors.grey;
    }
  }

  Future<void> _editUser(AdminUser user) async {
    final changed = await showDialog<bool>(context: context, builder: (_) => _EditUserDialog(user: user));
    if (changed == true) _load();
  }

  Future<void> _toggleSuspend(AdminUser user) async {
    try {
      await _service.toggleSuspendUser(user.id);
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _confirmDelete(AdminUser user) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Eliminar usuario', style: TextStyle(color: Colors.white)),
        content: Text('¿Eliminar a ${user.displayName.isNotEmpty ? user.displayName : user.email}?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (ok == true) {
      try {
        await _service.deleteUser(user.id);
        await _load();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: Color(0xFF1A8CFF)));
    if (_users == null) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('Error al cargar', style: TextStyle(color: Colors.white.withValues(alpha: 0.4))),
      const SizedBox(height: 16),
      ElevatedButton(onPressed: () { setState(() => _loading = true); _load(); }, child: const Text('Reintentar')),
    ]));
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _users!.length,
        itemBuilder: (_, i) {
          final u = _users![i];
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: u.suspendido ? Colors.red.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.06)),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: u.rol != 'admin' ? () => _editUser(u) : null,
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: _roleColor(u.rol).withValues(alpha: 0.2),
                    backgroundImage: u.avatar != null ? NetworkImage('${ApiClient.defaultBaseUrl.replaceAll('/api', '')}${u.avatar}') : null,
                    child: u.avatar == null
                        ? Text((u.nombre ?? u.email)[0].toUpperCase(), style: TextStyle(color: _roleColor(u.rol), fontWeight: FontWeight.bold))
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(u.displayName.isNotEmpty ? u.displayName : u.email,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                    Text(u.email, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _roleColor(u.rol).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(u.rol ?? '', style: TextStyle(color: _roleColor(u.rol), fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                    if (u.rol != 'admin') ...[
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => _toggleSuspend(u),
                        child: Icon(
                          u.suspendido ? Icons.check_circle_outline : Icons.block,
                          size: 18, color: u.suspendido ? Colors.greenAccent : Colors.orangeAccent,
                        ),
                      ),
                    ],
                  ]),
                  if (u.suspendido)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Suspendido', style: TextStyle(color: Colors.redAccent.withValues(alpha: 0.7), fontSize: 10, fontWeight: FontWeight.w600)),
                    ),
                ]),
                if (u.rol != 'admin') ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _confirmDelete(u),
                    child: Icon(Icons.delete_outline, size: 18, color: Colors.redAccent.withValues(alpha: 0.6)),
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

// ─── DRIVERS TAB ───────────────────────────────────────────────────────

class _DriversTab extends StatefulWidget {
  const _DriversTab();
  @override
  State<_DriversTab> createState() => _DriversTabState();
}

class _DriversTabState extends State<_DriversTab> {
  final _service = AdminService();
  List<AdminDriver>? _drivers;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final drivers = await _service.getDrivers();
      if (mounted) setState(() { _drivers = drivers; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _toggleSuspend(AdminDriver d) async {
    try {
      await _service.toggleSuspendUser(d.usuarioId);
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: Color(0xFF1A8CFF)));
    if (_drivers == null) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('Error al cargar', style: TextStyle(color: Colors.white.withValues(alpha: 0.4))),
      const SizedBox(height: 16),
      ElevatedButton(onPressed: () { setState(() => _loading = true); _load(); }, child: const Text('Reintentar')),
    ]));
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _drivers!.length,
        itemBuilder: (_, i) {
          final d = _drivers![i];
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: d.suspendido ? Colors.red.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.06)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF1A8CFF).withValues(alpha: 0.2),
                  child: Text(d.placa[0].toUpperCase(), style: const TextStyle(color: Color(0xFF1A8CFF), fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(d.displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                    Text('${d.placa} · ${d.tipoVehiculo ?? ''}', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: d.online ? Colors.green.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(d.online ? 'En línea' : 'Offline', style: TextStyle(
                        color: d.online ? Colors.greenAccent : Colors.grey,
                        fontSize: 10, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _toggleSuspend(d),
                      child: Icon(
                        d.suspendido ? Icons.check_circle_outline : Icons.block,
                        size: 18, color: d.suspendido ? Colors.greenAccent : Colors.orangeAccent,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  if (d.suspendido)
                    Text('Suspendido', style: TextStyle(color: Colors.redAccent.withValues(alpha: 0.7), fontSize: 10, fontWeight: FontWeight.w600))
                  else
                    Text('${d.totalViajes ?? 0} viajes', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11)),
                ]),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── TRIPS TAB ─────────────────────────────────────────────────────────

class _TripsTab extends StatefulWidget {
  const _TripsTab();
  @override
  State<_TripsTab> createState() => _TripsTabState();
}

class _TripsTabState extends State<_TripsTab> {
  final _service = AdminService();
  List<AdminTrip>? _trips;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final trips = await _service.getTrips();
      if (mounted) setState(() { _trips = trips; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Color _estadoColor(String estado) {
    switch (estado) {
      case 'pendiente': return Colors.orangeAccent;
      case 'aceptado': return const Color(0xFF1A8CFF);
      case 'en_curso': return Colors.purpleAccent;
      case 'completado': return Colors.greenAccent;
      case 'finalizado': return Colors.green;
      case 'cancelado': return Colors.redAccent;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: Color(0xFF1A8CFF)));
    if (_trips == null) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('Error al cargar', style: TextStyle(color: Colors.white.withValues(alpha: 0.4))),
      const SizedBox(height: 16),
      ElevatedButton(onPressed: () { setState(() => _loading = true); _load(); }, child: const Text('Reintentar')),
    ]));
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _trips!.length,
        itemBuilder: (_, i) {
          final t = _trips![i];
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withValues(alpha: 0.06))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('#${t.id}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15))),
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: _estadoColor(t.estado).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                  child: Text(t.estado, style: TextStyle(color: _estadoColor(t.estado), fontSize: 11, fontWeight: FontWeight.w600))),
              ]),
              const SizedBox(height: 10),
              _tripRow(Icons.person, 'Cliente', t.clienteNombre),
              _tripRow(Icons.local_shipping, 'Conductor', t.conductorNombre.isNotEmpty ? t.conductorNombre : '—'),
              _tripRow(Icons.location_on, 'Origen', t.origenDireccion),
              _tripRow(Icons.flag, 'Destino', t.destinoDireccion),
              if (t.carga != null && t.carga!.isNotEmpty) _tripRow(Icons.inventory, 'Carga', t.carga!),
              _tripRow(Icons.attach_money, 'Precio', '\$${(t.precioFinal ?? t.precioEstimado ?? 0).toStringAsFixed(2)}'),
            ]),
          );
        },
      ),
    );
  }

  Widget _tripRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(children: [
      Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.3)),
      const SizedBox(width: 8),
      Text('$label: ', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
      Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 12))),
    ]),
  );
}

// ─── EARNINGS TAB ──────────────────────────────────────────────────────

class _EarningsTab extends StatefulWidget {
  const _EarningsTab();
  @override
  State<_EarningsTab> createState() => _EarningsTabState();
}

class _EarningsTabState extends State<_EarningsTab> {
  final _service = AdminService();
  List<AdminEarning>? _earnings;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final earnings = await _service.getEarnings();
      if (mounted) setState(() { _earnings = earnings; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: Color(0xFF1A8CFF)));
    if (_earnings == null) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('Error al cargar', style: TextStyle(color: Colors.white.withValues(alpha: 0.4))),
      const SizedBox(height: 16),
      ElevatedButton(onPressed: () { setState(() => _loading = true); _load(); }, child: const Text('Reintentar')),
    ]));
    if (_earnings!.isEmpty) return Center(child: Text('Sin ganancias registradas', style: TextStyle(color: Colors.white.withValues(alpha: 0.3))));
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _earnings!.length,
        itemBuilder: (_, i) {
          final e = _earnings![i];
          final conductor = e.conductor;
          final nombre = conductor != null
              ? '${conductor['nombre'] ?? ''} ${conductor['apellido'] ?? ''}'.trim()
              : 'Conductor #${e.conductorId}';
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withValues(alpha: 0.06))),
            child: Row(children: [
              CircleAvatar(radius: 18, backgroundColor: Colors.greenAccent.withValues(alpha: 0.2),
                child: const Icon(Icons.monetization_on, size: 18, color: Colors.greenAccent)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('\$${e.monto.toStringAsFixed(2)}', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                if (nombre.isNotEmpty) Text(nombre, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
                if (e.createdAt != null) Text(e.createdAt!, style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 11)),
              ])),
              if (e.viaje != null)
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFF1A8CFF).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                  child: Text('Viaje #${e.viajeId}', style: const TextStyle(color: Color(0xFF1A8CFF), fontSize: 10, fontWeight: FontWeight.w600))),
            ]),
          );
        },
      ),
    );
  }
}
