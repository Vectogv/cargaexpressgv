import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../contracts/validacion_usuario.dart';
import '../../services/api_client.dart';
import '../../services/api/http_client.dart' show ApiException;
import '../../widgets/media_image.dart';
import '../user/auth_screen.dart';

/// Cuerpo de PUT /api/users/profile (app/validators/profile.ts): nombre,
/// apellido y correo vacíos no se envían (no se borran); teléfono y contacto
/// de emergencia vacíos se envían como null (el backend los acepta nulos).
Map<String, dynamic> cuerpoActualizacionPerfil({
  required String nombre,
  required String apellido,
  required String email,
  required String telefono,
  required String contactoNombre,
  required String contactoTelefono,
}) {
  String? opcional(String v) => v.trim().isEmpty ? null : v.trim();
  return {
    if (nombre.trim().isNotEmpty) 'nombre': nombre.trim(),
    if (apellido.trim().isNotEmpty) 'apellido': apellido.trim(),
    if (email.trim().isNotEmpty) 'email': email.trim(),
    'telefono': opcional(telefono),
    'contactoEmergenciaNombre': opcional(contactoNombre),
    'contactoEmergenciaTelefono': opcional(contactoTelefono),
  };
}

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

  bool _saliendo = false;

  /// Igual que el inicio: esperar a que se revoque la sesión y se limpien los
  /// tokens antes de ir al login (logout() no lanza y tiene timeout de 5 s).
  Future<void> _logout() async {
    if (_saliendo) return;
    setState(() => _saliendo = true);
    await ApiClient.instance.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const AuthScreen()), (_) => false);
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 75,
    );
    if (picked == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await picked.readAsBytes();
      // Comprimida a JPEG por image_picker → extensión .jpg.
      final url = await ApiClient.instance.uploadAvatar(bytes, 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg');
      if (mounted && url.isNotEmpty) {
        setState(() { _profile?['avatar'] = url; });
        messenger.showSnackBar(const SnackBar(content: Text('Avatar actualizado')));
      }
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: ${e.toString().replaceFirst("Exception: ", "")}')));
    }
  }

  Future<void> _editInfo() async {
    // El diálogo es dueño de sus controladores: se liberan cuando termina su
    // animación de salida (antes se liberaban aquí mientras aún se dibujaba).
    final body = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _EditarPerfilDialog(perfil: _profile ?? const {}),
    );
    if (body == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ApiClient.instance.updateProfile(body);
      await _loadProfile();
      messenger.showSnackBar(const SnackBar(content: Text('Perfil actualizado')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: ${e.toString().replaceFirst("Exception: ", "")}')));
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
                MediaAvatar(
                  path: avatar,
                  name: nombre,
                  radius: 35,
                  backgroundColor: _primaryDark,
                  foregroundColor: Colors.white,
                  fontSize: 22,
                  border: Border.all(color: Colors.grey.shade200, width: 2),
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
          _buildMenuItem(Icons.person_outline, 'Informaci\u00f3n personal', _editInfo),
          _buildMenuItem(Icons.logout, 'Cerrar sesi\u00f3n', _saliendo ? null : _logout),
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

/// Formulario de edición del perfil. Devuelve el cuerpo para
/// PUT /api/users/profile, o null si se cancela.
class _EditarPerfilDialog extends StatefulWidget {
  final Map<String, dynamic> perfil;
  const _EditarPerfilDialog({required this.perfil});

  @override
  State<_EditarPerfilDialog> createState() => _EditarPerfilDialogState();
}

class _EditarPerfilDialogState extends State<_EditarPerfilDialog> {
  late final _nombre = _ctrl('nombre');
  late final _apellido = _ctrl('apellido');
  late final _email = _ctrl('email');
  late final _telefono = _ctrl('telefono');
  late final _contactoNombre = _ctrl('contactoEmergenciaNombre');
  late final _contactoTelefono = _ctrl('contactoEmergenciaTelefono');
  String? _errorEmail;

  TextEditingController _ctrl(String campo) =>
      TextEditingController(text: widget.perfil[campo]?.toString() ?? '');

  @override
  void dispose() {
    for (final c in [_nombre, _apellido, _email, _telefono, _contactoNombre, _contactoTelefono]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _campo(TextEditingController c, String label, int max,
          {TextInputType tipo = TextInputType.text, String? error}) =>
      TextField(
        controller: c,
        keyboardType: tipo,
        inputFormatters: [LengthLimitingTextInputFormatter(max)],
        decoration: InputDecoration(labelText: label, errorText: error),
      );

  void _guardar() {
    // Correo vacío: no se cambia. Con texto, debe ser válido.
    final email = _email.text.trim();
    final error = email.isEmpty ? null : validarEmail(email);
    if (error != null) {
      setState(() => _errorEmail = error);
      return;
    }
    Navigator.pop(
      context,
      cuerpoActualizacionPerfil(
        nombre: _nombre.text,
        apellido: _apellido.text,
        email: _email.text,
        telefono: _telefono.text,
        contactoNombre: _contactoNombre.text,
        contactoTelefono: _contactoTelefono.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar perfil'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _campo(_nombre, 'Nombre', LimitesUsuario.nombre),
            const SizedBox(height: 8),
            _campo(_apellido, 'Apellido', LimitesUsuario.apellido),
            const SizedBox(height: 8),
            _campo(_email, 'Email', LimitesUsuario.email, tipo: TextInputType.emailAddress, error: _errorEmail),
            const SizedBox(height: 8),
            _campo(_telefono, 'Teléfono', LimitesUsuario.telefono, tipo: TextInputType.phone),
            const SizedBox(height: 16),
            _campo(_contactoNombre, 'Contacto de emergencia', LimitesUsuario.contactoNombre),
            const SizedBox(height: 8),
            _campo(_contactoTelefono, 'Teléfono del contacto', LimitesUsuario.contactoTelefono,
                tipo: TextInputType.phone),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(onPressed: _guardar, child: const Text('Guardar')),
      ],
    );
  }
}
