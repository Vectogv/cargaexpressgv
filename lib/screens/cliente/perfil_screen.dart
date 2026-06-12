import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_client.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  Map<String, dynamic>? _profile;
  bool _loading = true;
  String? _error;

  static const Color _primaryDark = Color(0xFF1A3C6E);
  static const Color _textDark = Color(0xFF1A1A2E);
  static const Color _textGrey = Color(0xFF757575);
  static const Color _bgLight = Color(0xFFF5F7FA);
  static const Color _white = Colors.white;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final data = await ApiClient.instance.getProfile();
      if (mounted) setState(() { _profile = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    try {
      final bytes = await picked.readAsBytes();
      final url = await ApiClient.instance.uploadAvatar(bytes, picked.name);
      if (mounted && url.isNotEmpty) {
        setState(() { _profile?['avatar'] = url; });
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Avatar actualizado')));
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString().replaceFirst("Exception: ", "")}')));
      }
    }
  }

  Future<void> _editInfo() async {
    final nombreCtrl = TextEditingController(text: _profile?['nombre'] as String? ?? '');
    final apellidoCtrl = TextEditingController(text: _profile?['apellido'] as String? ?? '');
    final emailCtrl = TextEditingController(text: _profile?['email'] as String? ?? '');
    final telefonoCtrl = TextEditingController(text: _profile?['telefono'] as String? ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar perfil'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre')),
              const SizedBox(height: 8),
              TextField(controller: apellidoCtrl, decoration: const InputDecoration(labelText: 'Apellido')),
              const SizedBox(height: 8),
              TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 8),
              TextField(controller: telefonoCtrl, decoration: const InputDecoration(labelText: 'Teléfono'), keyboardType: TextInputType.phone),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
        ],
      ),
    );

    if (result != true) return;
    try {
      await ApiClient.instance.updateProfile({
        'nombre': nombreCtrl.text.trim(),
        'apellido': apellidoCtrl.text.trim(),
        'email': emailCtrl.text.trim(),
        'telefono': telefonoCtrl.text.trim(),
      });
      await _loadProfile();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perfil actualizado')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString().replaceFirst("Exception: ", "")}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        backgroundColor: _white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 20, color: _textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Perfil', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _textDark)),
        actions: [
          IconButton(
            icon: Icon(Icons.edit_outlined, size: 22, color: _textDark),
            onPressed: _editInfo,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildProfileCard(),
                      const SizedBox(height: 12),
                      _buildMenuItems(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildProfileCard() {
    final nombre = '${_profile?['nombre'] ?? ApiClient.instance.nombre ?? ''} ${_profile?['apellido'] ?? ''}'.trim();
    final email = _profile?['email'] as String? ?? ApiClient.instance.email ?? '';
    final avatar = _profile?['avatar'] as String?;
    final telefono = _profile?['telefono'] as String?;

    return Container(
      color: _white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Row(
        children: [
          GestureDetector(
            onTap: _pickAvatar,
            child: Stack(
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade200, width: 2),
                    image: avatar != null && avatar.isNotEmpty
                        ? DecorationImage(image: NetworkImage(avatar), fit: BoxFit.cover)
                        : const DecorationImage(
                            image: NetworkImage('https://randomuser.me/api/portraits/men/32.jpg'),
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: _primaryDark,
                      shape: BoxShape.circle,
                      border: Border.all(color: _white, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre.isNotEmpty ? nombre : 'Cliente',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E)),
                ),
                const SizedBox(height: 2),
                Text(email, style: TextStyle(fontSize: 12, color: _textGrey)),
                if (telefono != null && telefono.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(telefono, style: TextStyle(fontSize: 12, color: _textGrey)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItems() {
    return Container(
      color: _white,
      child: Column(
        children: [
          _buildMenuItem(Icons.person_outline, 'Información personal', _editInfo),
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String label, VoidCallback? onTap) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Icon(icon, size: 22, color: _textDark),
                const SizedBox(width: 14),
                Expanded(child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500))),
                Icon(Icons.chevron_right, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
        const Divider(height: 1, indent: 56, endIndent: 0),
      ],
    );
  }
}
