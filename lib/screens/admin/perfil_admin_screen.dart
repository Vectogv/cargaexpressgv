import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/media.dart';
import '../../services/api/http_client.dart';
import 'admin_common.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = true;
  bool _uploading = false;
  String? _error;
  /// GET /api/admin/profile → {id, nombre, apellido, email, telefono, avatar, createdAt}
  Map<String, dynamic> _profile = {};
  // Controladores del diálogo: viven con la pantalla (se liberan en dispose).
  final _nombreCtrl = TextEditingController();
  final _apellidoCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchProfile() async {
    try {
      final data = await HttpClient.get('/api/admin/profile', auth: true);
      if (!mounted) return;
      setState(() {
        _profile = data;
        _profile['miembro'] = DateTime.tryParse(data['createdAt']?.toString() ?? '')?.year;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = adminErrorText(e);
        _loading = false;
      });
    }
  }

  Future<void> _editProfile() async {
    final nombreCtrl = _nombreCtrl..text = _profile['nombre']?.toString() ?? '';
    final apellidoCtrl = _apellidoCtrl..text = _profile['apellido']?.toString() ?? '';
    final emailCtrl = _emailCtrl..text = _profile['email']?.toString() ?? '';

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
      await HttpClient.put('/api/admin/profile', body: result, auth: true);
      adminSnack(this, 'Perfil actualizado');
      _fetchProfile();
    } catch (e) {
      adminSnack(this, adminErrorText(e), error: true);
    }
  }

  /// POST /api/admin/profile/avatar es multipart con el campo `file`
  /// (antes se enviaba una URL en JSON, que el backend ignora).
  Future<void> _uploadAvatar() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    setState(() => _uploading = true);
    try {
      final bytes = await picked.readAsBytes();
      final res = await HttpClient.uploadFile(
        '/api/admin/profile/avatar',
        bytes: bytes,
        filename: picked.name,
        fieldName: 'file',
        auth: true,
      );
      if (!mounted) return;
      setState(() => _profile['avatar'] = res['avatar'] ?? _profile['avatar']);
      adminSnack(this, 'Avatar actualizado');
    } catch (e) {
      adminSnack(this, adminErrorText(e), error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null && _profile.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () {
                              setState(() => _loading = true);
                              _fetchProfile();
                            },
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
                  )
                : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    // Avatar: ruta relativa del backend → resolveMediaUrl.
                    Builder(builder: (_) {
                      final avatarUrl = resolveMediaUrl(_profile['avatar']?.toString());
                      return CircleAvatar(
                        radius: 56,
                        backgroundColor: Colors.grey.shade200,
                        backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                        onBackgroundImageError: avatarUrl != null ? (_, _) {} : null,
                        child: _uploading
                            ? const CircularProgressIndicator()
                            : avatarUrl == null
                                ? const Icon(Icons.person, size: 56, color: Colors.white54)
                                : null,
                      );
                    }),
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
