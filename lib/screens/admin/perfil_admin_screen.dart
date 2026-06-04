import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../services/api_client.dart';

Map<String, String> get _authHeaders => {
  'Content-Type': 'application/json',
  'Authorization': 'Bearer ${ApiClient.instance.token}',
};

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = true;
  Map<String, dynamic> _profile = {};

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final res = await http.get(
        Uri.parse('${ApiClient.baseUrl}/api/admin/profile'),
        headers: _authHeaders,
      );
      if (res.statusCode == 200) {
        setState(() {
          _profile = jsonDecode(res.body);
          _loading = false;
        });
      } else {
        _useFallback();
      }
    } catch (_) {
      _useFallback();
    }
  }

  void _useFallback() {
    setState(() {
      _profile = {
        'nombre': 'Admin',
        'apellido': 'Principal',
        'email': 'admin@cargaexpress.com',
        'avatar': null,
      };
      _loading = false;
    });
  }

  Future<void> _editProfile() async {
    final nombreCtrl = TextEditingController(text: _profile['nombre'] ?? '');
    final apellidoCtrl = TextEditingController(text: _profile['apellido'] ?? '');
    final emailCtrl = TextEditingController(text: _profile['email'] ?? '');

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar Perfil'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              TextField(
                controller: apellidoCtrl,
                decoration: const InputDecoration(labelText: 'Apellido'),
              ),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, {
              'nombre': nombreCtrl.text.trim(),
              'apellido': apellidoCtrl.text.trim(),
              'email': emailCtrl.text.trim(),
            }),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (result == null) return;

    try {
      final res = await http.put(
        Uri.parse('${ApiClient.baseUrl}/api/admin/profile'),
        headers: _authHeaders,
        body: jsonEncode(result),
      );
      if (res.statusCode == 200) {
        _fetchProfile();
      }
    } catch (_) {
      setState(() {
        _profile['nombre'] = result['nombre'];
        _profile['apellido'] = result['apellido'];
        _profile['email'] = result['email'];
      });
    }
  }

  Future<void> _uploadAvatar() async {
    final urlCtrl = TextEditingController();

    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Actualizar Avatar'),
        content: TextField(
          controller: urlCtrl,
          decoration: const InputDecoration(
            labelText: 'URL de la imagen',
            hintText: 'https://ejemplo.com/avatar.jpg',
          ),
          keyboardType: TextInputType.url,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, urlCtrl.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (url == null || url.isEmpty) return;

    try {
      final res = await http.post(
        Uri.parse('${ApiClient.baseUrl}/api/admin/profile/avatar'),
        headers: _authHeaders,
        body: jsonEncode({'url': url}),
      );
      if (res.statusCode == 200) {
        _fetchProfile();
      }
    } catch (_) {
      setState(() {
        _profile['avatar'] = url;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    CircleAvatar(
                      radius: 56,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: _profile['avatar'] != null
                          ? NetworkImage(_profile['avatar'] as String)
                          : null,
                      child: _profile['avatar'] == null
                          ? const Icon(Icons.person, size: 56, color: Colors.white54)
                          : null,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '${_profile['nombre'] ?? ''} ${_profile['apellido'] ?? ''}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _profile['email'] ?? '',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: _StatBox(
                            label: 'Viajes',
                            value: '${_profile['viajes'] ?? 0}',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatBox(
                            label: 'Rating',
                            value: '${_profile['rating'] ?? '--'}',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatBox(
                            label: 'Miembro',
                            value: '${_profile['miembro'] ?? '--'}',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 36),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _editProfile,
                        icon: const Icon(Icons.edit),
                        label: const Text('Editar Perfil'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1565C0),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _uploadAvatar,
                        icon: const Icon(Icons.cloud_upload),
                        label: const Text('Subir Avatar'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1565C0),
                          side: const BorderSide(color: Color(0xFF1565C0)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;

  const _StatBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
