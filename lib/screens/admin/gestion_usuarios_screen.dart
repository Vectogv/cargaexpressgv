import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../services/api_client.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  List<dynamic> _users = [];
  bool _loading = true;

  Map<String, String> get _authHeaders => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${ApiClient.instance.token}',
  };

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() => _loading = true);
    try {
      final res = await http.get(
        Uri.parse('${ApiClient.baseUrl}/api/admin/users'),
        headers: _authHeaders,
      );
      if (res.statusCode == 200) {
        setState(() {
          _users = jsonDecode(res.body) as List<dynamic>;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _toggleSuspend(dynamic user) async {
    try {
      final res = await http.put(
        Uri.parse('${ApiClient.baseUrl}/api/admin/users/${user['id']}/suspend'),
        headers: _authHeaders,
      );
      if (res.statusCode == 200) {
        _fetchUsers();
      }
    } catch (_) {}
  }

  Future<void> _deleteUser(dynamic user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar usuario'),
        content: Text('¿Eliminar a ${user['nombre']} ${user['apellido']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final res = await http.delete(
        Uri.parse('${ApiClient.baseUrl}/api/admin/users/${user['id']}'),
        headers: _authHeaders,
      );
      if (res.statusCode == 200) {
        _fetchUsers();
      }
    } catch (_) {}
  }

  Future<void> _editUser(dynamic user) async {
    final nombreCtrl = TextEditingController(text: user['nombre'] ?? '');
    final apellidoCtrl = TextEditingController(text: user['apellido'] ?? '');
    final emailCtrl = TextEditingController(text: user['email'] ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar usuario'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre')),
            TextField(controller: apellidoCtrl, decoration: const InputDecoration(labelText: 'Apellido')),
            TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
        ],
      ),
    );
    if (result != true) return;

    try {
      await http.put(
        Uri.parse('${ApiClient.baseUrl}/api/admin/users/${user['id']}'),
        headers: _authHeaders,
        body: jsonEncode({
          'nombre': nombreCtrl.text,
          'apellido': apellidoCtrl.text,
          'email': emailCtrl.text,
        }),
      );
      _fetchUsers();
    } catch (_) {}
  }

  Future<void> _updateAvatar(dynamic user) async {
    final urlCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Actualizar avatar'),
        content: TextField(
          controller: urlCtrl,
          decoration: const InputDecoration(labelText: 'URL del avatar'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
        ],
      ),
    );
    if (result != true || urlCtrl.text.trim().isEmpty) return;

    try {
      await http.put(
        Uri.parse('${ApiClient.baseUrl}/api/admin/users/${user['id']}/avatar'),
        headers: _authHeaders,
        body: jsonEncode({'url': urlCtrl.text.trim()}),
      );
      _fetchUsers();
    } catch (_) {}
  }

  Future<void> _clearDebt(dynamic user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Limpiar deuda'),
        content: Text('¿Limpiar la deuda de ${user['nombre']} ${user['apellido']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Limpiar', style: TextStyle(color: Colors.orange))),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await http.put(
        Uri.parse('${ApiClient.baseUrl}/api/admin/users/${user['id']}/clear-debt'),
        headers: _authHeaders,
      );
      _fetchUsers();
    } catch (_) {}
  }

  Future<void> _assignModerator(dynamic user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Asignar moderador'),
        content: Text('¿Asignar a ${user['nombre']} ${user['apellido']} como moderador?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Asignar', style: TextStyle(color: Colors.blue))),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await http.put(
        Uri.parse('${ApiClient.baseUrl}/api/admin/users/${user['id']}/moderator'),
        headers: _authHeaders,
      );
      _fetchUsers();
    } catch (_) {}
  }

  Future<void> _assignLeader(dynamic user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Asignar líder'),
        content: Text('¿Asignar a ${user['nombre']} ${user['apellido']} como líder?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Asignar', style: TextStyle(color: Colors.blue))),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await http.put(
        Uri.parse('${ApiClient.baseUrl}/api/admin/users/${user['id']}/leader'),
        headers: _authHeaders,
      );
      _fetchUsers();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: const Text(
          'Gestión de Usuarios',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black54),
            onPressed: _fetchUsers,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? const Center(child: Text('No hay usuarios'))
              : RefreshIndicator(
                  onRefresh: _fetchUsers,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _users.length,
                    itemBuilder: (_, i) {
                      final u = _users[i];
                      final suspendido = u['suspendido'] == true;
                      final isAdmin = u['rol'] == 'admin';
                      return Card(
                        color: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: suspendido ? Colors.grey : const Color(0xFF1565C0),
                            child: Text(
                              '${(u['nombre'] as String)[0]}${(u['apellido'] as String)[0]}',
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ),
                          title: Text('${u['nombre']} ${u['apellido']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('${u['email']} • ${u['rol']}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!isAdmin)
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                  onPressed: () => _editUser(u),
                                ),
                              if (!isAdmin)
                                IconButton(
                                  icon: const Icon(Icons.image, color: Colors.teal, size: 20),
                                  onPressed: () => _updateAvatar(u),
                                ),
                              if (!isAdmin)
                                IconButton(
                                  icon: const Icon(Icons.attach_money, color: Colors.orange, size: 20),
                                  onPressed: () => _clearDebt(u),
                                ),
                              if (!isAdmin)
                                IconButton(
                                  icon: const Icon(Icons.verified_user, color: Colors.purple, size: 20),
                                  onPressed: () => _assignModerator(u),
                                ),
                              if (!isAdmin)
                                IconButton(
                                  icon: const Icon(Icons.emoji_events, color: Colors.amber, size: 20),
                                  onPressed: () => _assignLeader(u),
                                ),
                              IconButton(
                                icon: Icon(
                                  suspendido ? Icons.lock_open : Icons.lock,
                                  color: suspendido ? Colors.green : Colors.orange,
                                  size: 20,
                                ),
                                onPressed: () => _toggleSuspend(u),
                              ),
                              if (!isAdmin)
                                IconButton(
                                  icon: const Icon(Icons.delete_forever, color: Colors.red, size: 20),
                                  onPressed: () => _deleteUser(u),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
