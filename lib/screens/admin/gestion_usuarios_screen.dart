import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api/http_client.dart';
import 'admin_common.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  List<dynamic> _users = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _page = 1;
  String? _error;
  String _searchQuery = '';
  Timer? _searchDebounce;
  final _searchCtrl = TextEditingController();
  // Controladores del diálogo de edición: viven con la pantalla para no
  // liberarlos mientras el diálogo aún anima su cierre.
  final _editNombre = TextEditingController();
  final _editApellido = TextEditingController();
  final _editEmail = TextEditingController();

  /// El backend limita `limit` a 100; la paginación total va en cabeceras
  /// (X-Total-Count) que HttpClient.getList no expone, así que se pagina
  /// hasta recibir una página incompleta.
  static const _pageSize = 100;
  static const _roles = {'admin', 'cliente', 'conductor', 'moderador', 'lider'};

  // ── Design tokens ──────────────────────────────────────────────
  static const _bg       = Color(0xFF0D1117);
  static const _surface  = Color(0xFF161B22);
  static const _card     = Color(0xFF1C2330);
  static const _border   = Color(0xFF30363D);
  static const _accent   = Color(0xFF238636);   // green-ish
  static const _blue     = Color(0xFF1F6FEB);
  static const _amber    = Color(0xFFD29922);
  static const _red      = Color(0xFFDA3633);
  static const _teal     = Color(0xFF1B7C83);
  static const _purple   = Color(0xFF8957E5);
  static const _textPri  = Color(0xFFE6EDF3);
  static const _textSec  = Color(0xFF8B949E);

  /// Id de usuario tolerante al contrato Mongo (`_id`) y al alias (`id`).
  dynamic _userId(dynamic user) => user['_id'] ?? user['id'];

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _editNombre.dispose();
    _editApellido.dispose();
    _editEmail.dispose();
    super.dispose();
  }

  /// La búsqueda se hace en el backend (`search` por nombre/apellido/email/
  /// teléfono); si el texto es un rol exacto se envía como `rol`.
  String _query(int page) {
    final q = _searchQuery.trim().toLowerCase();
    final params = <String, String>{'page': '$page', 'limit': '$_pageSize'};
    if (q.isNotEmpty) {
      if (_roles.contains(q)) {
        params['rol'] = q;
      } else {
        params['search'] = _searchQuery.trim();
      }
    }
    return Uri(path: '/api/admin/users', queryParameters: params).toString();
  }

  /// Descarta respuestas de búsquedas anteriores que lleguen tarde.
  int _reqSeq = 0;

  Future<void> _fetchUsers() async {
    final seq = ++_reqSeq;
    setState(() => _loading = true);
    try {
      final data = await HttpClient.getList(_query(1), auth: true);
      if (!mounted || seq != _reqSeq) return;
      setState(() {
        _users = data;
        _page = 1;
        _hasMore = data.length >= _pageSize;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || seq != _reqSeq) return;
      setState(() {
        _error = adminErrorText(e);
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final seq = _reqSeq;
      final data = await HttpClient.getList(_query(_page + 1), auth: true);
      if (!mounted || seq != _reqSeq) return;
      setState(() {
        _users = [..._users, ...data];
        _page += 1;
        _hasMore = data.length >= _pageSize;
      });
    } catch (e) {
      _showSnack(adminErrorText(e), _red);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _onSearchChanged(String v) {
    setState(() => _searchQuery = v);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), _fetchUsers);
  }

  Future<void> _toggleSuspend(dynamic user) async {
    try {
      final res = await HttpClient.put('/api/admin/users/${_userId(user)}/suspend', auth: true);
      _showSnack(res['suspendido'] == true ? 'Usuario suspendido' : 'Usuario reactivado', _amber);
      _fetchUsers();
    } catch (e) {
      _showSnack(adminErrorText(e), _red);
    }
  }

  Future<void> _deleteUser(dynamic user) async {
    final confirm = await _showConfirmDialog(
      title: 'Eliminar usuario',
      message: '¿Eliminar a ${user['nombre']} ${user['apellido']}? Esta acción no se puede deshacer.',
      confirmLabel: 'Eliminar',
      confirmColor: _red,
      icon: Icons.delete_forever_rounded,
    );
    if (confirm != true) return;
    try {
      await HttpClient.delete('/api/admin/users/${_userId(user)}', auth: true);
      _fetchUsers();
      _showSnack('Usuario eliminado', _red);
    } catch (e) {
      _showSnack(adminErrorText(e), _red);
    }
  }

  Future<void> _editUser(dynamic user) async {
    final nombreCtrl   = _editNombre..text = user['nombre']?.toString() ?? '';
    final apellidoCtrl = _editApellido..text = user['apellido']?.toString() ?? '';
    final emailCtrl    = _editEmail..text = user['email']?.toString() ?? '';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => _StyledDialog(
        title: 'Editar usuario',
        icon: Icons.edit_rounded,
        iconColor: _blue,
        onCancel: () => Navigator.pop(ctx, false),
        onConfirm: () => Navigator.pop(ctx, true),
        confirmLabel: 'Guardar',
        confirmColor: _blue,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DialogField(controller: nombreCtrl,   label: 'Nombre',   icon: Icons.person_rounded),
            const SizedBox(height: 12),
            _DialogField(controller: apellidoCtrl, label: 'Apellido', icon: Icons.person_outline_rounded),
            const SizedBox(height: 12),
            _DialogField(controller: emailCtrl,    label: 'Email',    icon: Icons.email_rounded),
          ],
        ),
      ),
    );
    if (result != true) return;
    try {
      await HttpClient.put(
        '/api/admin/users/${_userId(user)}',
        body: {
          'nombre':   nombreCtrl.text.trim(),
          'apellido': apellidoCtrl.text.trim(),
          'email':    emailCtrl.text.trim(),
        },
        auth: true,
      );
      _fetchUsers();
      _showSnack('Usuario actualizado', _blue);
    } catch (e) {
      _showSnack(adminErrorText(e), _red);
    }
  }

  Future<void> _updateAvatar(dynamic user) async {
    // Contrato real: PUT /api/admin/users/:id/avatar es multipart/form-data
    // con el campo `file` (imagen). Ya no se envía una URL en JSON.
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    try {
      await HttpClient.uploadFile(
        '/api/admin/users/${_userId(user)}/avatar',
        bytes: bytes,
        filename: picked.name,
        fieldName: 'file',
        auth: true,
        method: 'PUT',
      );
      _fetchUsers();
      _showSnack('Avatar actualizado', _teal);
    } catch (e) {
      _showSnack(adminErrorText(e), _red);
    }
  }

  Future<void> _clearDebt(dynamic user) async {
    final confirm = await _showConfirmDialog(
      title: 'Limpiar deuda',
      message: '¿Limpiar la deuda de ${user['nombre']} ${user['apellido']}?',
      confirmLabel: 'Limpiar',
      confirmColor: _amber,
      icon: Icons.attach_money_rounded,
    );
    if (confirm != true) return;
    try {
      await HttpClient.put('/api/admin/users/${_userId(user)}/clear-debt', auth: true);
      _fetchUsers();
      _showSnack('Deuda limpiada', _amber);
    } catch (e) {
      _showSnack(adminErrorText(e), _red);
    }
  }

  /// PUT /users/:id/moderator {esModerador, zonaModerador}. Sin body el
  /// backend no cambia nada, así que se pide la zona (cali|popayan|pasto)
  /// o se quita el rol si ya es moderador.
  Future<void> _assignModerator(dynamic user) async {
    final esModerador = user['esModerador'] == true;
    final zona = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: _surface,
        title: Text(
          esModerador ? 'Moderador (${user['zonaModerador'] ?? 'sin zona'})' : 'Asignar moderador',
          style: const TextStyle(color: _textPri, fontSize: 16),
        ),
        children: [
          for (final z in const ['cali', 'popayan', 'pasto'])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, z),
              child: Text('Zona: $z', style: const TextStyle(color: _textPri)),
            ),
          if (esModerador)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, ''),
              child: const Text('Quitar rol de moderador', style: TextStyle(color: _red)),
            ),
        ],
      ),
    );
    if (zona == null) return;
    final quitar = zona.isEmpty;
    try {
      await HttpClient.put(
        '/api/admin/users/${_userId(user)}/moderator',
        body: quitar ? {'esModerador': false} : {'esModerador': true, 'zonaModerador': zona},
        auth: true,
      );
      _fetchUsers();
      _showSnack(quitar ? 'Moderador removido' : 'Moderador asignado ($zona)', _purple);
    } catch (e) {
      _showSnack(adminErrorText(e), _red);
    }
  }

  /// PUT /users/:id/leader {esLider}: alterna el rol de líder.
  Future<void> _assignLeader(dynamic user) async {
    final esLider = user['esLider'] == true;
    final confirm = await _showConfirmDialog(
      title: esLider ? 'Quitar líder' : 'Asignar líder',
      message: esLider
          ? '¿Quitar a ${user['nombre']} ${user['apellido']} el rol de líder?'
          : '¿Asignar a ${user['nombre']} ${user['apellido']} como líder?',
      confirmLabel: esLider ? 'Quitar' : 'Asignar',
      confirmColor: _amber,
      icon: Icons.emoji_events_rounded,
    );
    if (confirm != true) return;
    try {
      await HttpClient.put(
        '/api/admin/users/${_userId(user)}/leader',
        body: {'esLider': !esLider},
        auth: true,
      );
      _fetchUsers();
      _showSnack(esLider ? 'Líder removido' : 'Líder asignado', _amber);
    } catch (e) {
      _showSnack(adminErrorText(e), _red);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
    required IconData icon,
  }) =>
      showDialog<bool>(
        context: context,
        builder: (ctx) => _StyledDialog(
          title: title,
          icon: icon,
          iconColor: confirmColor,
          onCancel: () => Navigator.pop(ctx, false),
          onConfirm: () => Navigator.pop(ctx, true),
          confirmLabel: confirmLabel,
          confirmColor: confirmColor,
          child: Text(message, style: const TextStyle(color: _textSec, fontSize: 14, height: 1.5)),
        ),
      );

  // ── Role badge ─────────────────────────────────────────────────

  Widget _roleBadge(String rol) {
    Color bg;
    Color fg;
    switch (rol) {
      case 'admin':
        bg = _red.withValues(alpha: .18);
        fg = _red;
        break;
      case 'moderador':
        bg = _purple.withValues(alpha: .18);
        fg = _purple;
        break;
      case 'lider':
        bg = _amber.withValues(alpha: .18);
        fg = _amber;
        break;
      default:
        bg = _border.withValues(alpha: .5);
        fg = _textSec;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(rol, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: .4)),
    );
  }

  // ── Action button ──────────────────────────────────────────────

  Widget _actionBtn({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required String tooltip,
  }) =>
      Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: .25)),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
        ),
      );

  // ── Build ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final users = _users;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _textSec, size: 18),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text(
          'Gestión de Usuarios',
          style: TextStyle(
            color: _textPri,
            fontWeight: FontWeight.w700,
            fontSize: 17,
            letterSpacing: -.3,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _border),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: _textSec, size: 20),
            tooltip: 'Actualizar',
            onPressed: _fetchUsers,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // ── Stats bar ───────────────────────────────────────────
          if (_users.isNotEmpty)
            Container(
              color: _surface,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  _StatChip(
                    label: 'Total',
                    value: '${_users.length}${_hasMore ? '+' : ''}',
                    color: _blue,
                  ),
                  const SizedBox(width: 8),
                  _StatChip(
                    label: 'Activos',
                    value: '${_users.where((u) => u['suspendido'] != true).length}',
                    color: _accent,
                  ),
                  const SizedBox(width: 8),
                  _StatChip(
                    label: 'Suspendidos',
                    value: '${_users.where((u) => u['suspendido'] == true).length}',
                    color: _red,
                  ),
                ],
              ),
            ),

          // ── Search bar ─────────────────────────────────────────
          // Siempre visible: la búsqueda es en el backend y puede dar 0 resultados.
          Container(
              color: _surface,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearchChanged,
                style: const TextStyle(color: _textPri, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre, email o rol…',
                  hintStyle: TextStyle(color: _textSec.withValues(alpha: .7), fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded, color: _textSec, size: 18),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, color: _textSec, size: 16),
                          onPressed: () {
                            _searchCtrl.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: _card,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: _border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: _border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _blue),
                  ),
                ),
              ),
            ),

          Container(height: 1, color: _border),

          // ── List ───────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: _blue,
                      strokeWidth: 2,
                    ),
                  )
                : users.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off_rounded, size: 48, color: _textSec.withValues(alpha: .4)),
                            const SizedBox(height: 12),
                            Text(
                              _error ?? (_searchQuery.isEmpty ? 'No hay usuarios' : 'Sin resultados'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _error != null ? _red : _textSec.withValues(alpha: .7),
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchUsers,
                        color: _blue,
                        backgroundColor: _card,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          itemCount: users.length + (_hasMore ? 1 : 0),
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (_, i) => i == users.length
                              ? Center(
                                  child: _loadingMore
                                      ? const Padding(
                                          padding: EdgeInsets.all(8),
                                          child: CircularProgressIndicator(color: _blue, strokeWidth: 2),
                                        )
                                      : TextButton(
                                          onPressed: _loadMore,
                                          child: const Text('Cargar más', style: TextStyle(color: _blue)),
                                        ),
                                )
                              : _UserCard(
                            user: users[i],
                            // Backend: rol + flags esModerador/esLider.
                            roleBadge: _roleBadge(users[i]['esModerador'] == true
                                ? 'moderador'
                                : users[i]['esLider'] == true
                                    ? 'lider'
                                    : users[i]['rol'] as String? ?? 'usuario'),
                            actionBtn: _actionBtn,
                            onEdit: _editUser,
                            onAvatar: _updateAvatar,
                            onClearDebt: _clearDebt,
                            onModerator: _assignModerator,
                            onLeader: _assignLeader,
                            onSuspend: _toggleSuspend,
                            onDelete: _deleteUser,
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

// ── User Card ───────────────────────────────────────────────────────────────

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.roleBadge,
    required this.actionBtn,
    required this.onEdit,
    required this.onAvatar,
    required this.onClearDebt,
    required this.onModerator,
    required this.onLeader,
    required this.onSuspend,
    required this.onDelete,
  });

  final dynamic user;
  final Widget roleBadge;
  final Widget Function({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required String tooltip,
  }) actionBtn;
  final Future<void> Function(dynamic) onEdit;
  final Future<void> Function(dynamic) onAvatar;
  final Future<void> Function(dynamic) onClearDebt;
  final Future<void> Function(dynamic) onModerator;
  final Future<void> Function(dynamic) onLeader;
  final Future<void> Function(dynamic) onSuspend;
  final Future<void> Function(dynamic) onDelete;

  static const _card    = Color(0xFF1C2330);
  static const _border  = Color(0xFF30363D);
  static const _textPri = Color(0xFFE6EDF3);
  static const _textSec = Color(0xFF8B949E);
  static const _red     = Color(0xFFDA3633);
  static const _blue    = Color(0xFF1F6FEB);
  static const _teal    = Color(0xFF1B7C83);
  static const _amber   = Color(0xFFD29922);
  static const _purple  = Color(0xFF8957E5);
  static const _accent  = Color(0xFF238636);

  String _initials() {
    final n = (user['nombre'] as String? ?? '?');
    final a = (user['apellido'] as String? ?? '?');
    return '${n.isNotEmpty ? n[0] : '?'}${a.isNotEmpty ? a[0] : '?'}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final suspendido = user['suspendido'] == true;
    final isAdmin    = user['rol'] == 'admin';
    final avatarColor = suspendido ? _textSec : _blue;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: suspendido ? _red.withValues(alpha: .3) : _border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ───────────────────────────────────────
            Row(
              children: [
                // Avatar
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: avatarColor.withValues(alpha: .15),
                    shape: BoxShape.circle,
                    border: Border.all(color: avatarColor.withValues(alpha: .4), width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      _initials(),
                      style: TextStyle(
                        color: avatarColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Name + email
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              '${user['nombre']} ${user['apellido']}',
                              style: const TextStyle(
                                color: _textPri,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (suspendido) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: _red.withValues(alpha: .15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: _red.withValues(alpha: .3)),
                              ),
                              child: const Text(
                                'SUSPENDIDO',
                                style: TextStyle(
                                  color: _red,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: .8,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user['email'] ?? '',
                        style: const TextStyle(color: _textSec, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                roleBadge,
              ],
            ),

            // ── Divider ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: _border),
            ),

            // ── Actions row ──────────────────────────────────────
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (!isAdmin)
                  actionBtn(
                    icon: Icons.edit_rounded,
                    color: _blue,
                    tooltip: 'Editar',
                    onTap: () => onEdit(user),
                  ),
                if (!isAdmin)
                  actionBtn(
                    icon: Icons.image_rounded,
                    color: _teal,
                    tooltip: 'Actualizar avatar',
                    onTap: () => onAvatar(user),
                  ),
                if (!isAdmin)
                  actionBtn(
                    icon: Icons.attach_money_rounded,
                    color: _amber,
                    tooltip: 'Limpiar deuda',
                    onTap: () => onClearDebt(user),
                  ),
                if (!isAdmin)
                  actionBtn(
                    icon: Icons.verified_user_rounded,
                    color: _purple,
                    tooltip: user['esModerador'] == true ? 'Moderador (zona / quitar)' : 'Asignar moderador',
                    onTap: () => onModerator(user),
                  ),
                if (!isAdmin)
                  actionBtn(
                    icon: Icons.emoji_events_rounded,
                    color: _amber,
                    tooltip: user['esLider'] == true ? 'Quitar líder' : 'Asignar líder',
                    onTap: () => onLeader(user),
                  ),
                actionBtn(
                  icon: suspendido ? Icons.lock_open_rounded : Icons.lock_rounded,
                  color: suspendido ? _accent : _amber,
                  tooltip: suspendido ? 'Reactivar' : 'Suspender',
                  onTap: () => onSuspend(user),
                ),
                if (!isAdmin)
                  actionBtn(
                    icon: Icons.delete_forever_rounded,
                    color: _red,
                    tooltip: 'Eliminar',
                    onTap: () => onDelete(user),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stat chip ───────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  static const _card   = Color(0xFF1C2330);
  static const _border = Color(0xFF30363D);
  static const _textSec = Color(0xFF8B949E);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: _textSec, fontSize: 12)),
        ],
      ),
    );
  }
}

// ── Styled dialog ───────────────────────────────────────────────────────────

class _StyledDialog extends StatelessWidget {
  const _StyledDialog({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.child,
    required this.onCancel,
    required this.onConfirm,
    required this.confirmLabel,
    required this.confirmColor,
  });

  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget child;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final String confirmLabel;
  final Color confirmColor;

  static const _surface = Color(0xFF161B22);
  static const _card    = Color(0xFF1C2330);
  static const _border  = Color(0xFF30363D);
  static const _textPri = Color(0xFFE6EDF3);
  static const _textSec = Color(0xFF8B949E);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon + title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: _textPri,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            child,
            const SizedBox(height: 24),
            // Buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: onCancel,
                    style: TextButton.styleFrom(
                      backgroundColor: _card,
                      foregroundColor: _textSec,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: _border),
                      ),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onConfirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: confirmColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(confirmLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Dialog field ────────────────────────────────────────────────────────────

class _DialogField extends StatelessWidget {
  const _DialogField({
    required this.controller,
    required this.label,
    required this.icon,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;

  static const _card    = Color(0xFF1C2330);
  static const _border  = Color(0xFF30363D);
  static const _textPri = Color(0xFFE6EDF3);
  static const _textSec = Color(0xFF8B949E);
  static const _blue    = Color(0xFF1F6FEB);

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: _textPri, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _textSec, fontSize: 13),
        prefixIcon: Icon(icon, color: _textSec, size: 18),
        filled: true,
        fillColor: _card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _blue),
        ),
      ),
    );
  }
}