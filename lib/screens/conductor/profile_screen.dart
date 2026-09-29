import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../contracts/validacion_usuario.dart';
import '../../services/api_client.dart';
import '../../services/api/http_client.dart' show ApiException;
import '../../widgets/media_image.dart';
import '../shared/ui_compartida.dart' show ColoresApp;
import 'documents_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _loading = true;
  String? _error;


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
    final nombreCtrl = TextEditingController(text: _profile?['nombre'] as String? ?? '');
    final apellidoCtrl = TextEditingController(text: _profile?['apellido'] as String? ?? '');
    final emailCtrl = TextEditingController(text: _profile?['email'] as String? ?? '');
    final telefonoCtrl = TextEditingController(text: _profile?['telefono'] as String? ?? '');

    String? errorTelefono;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Editar perfil'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre')),
                  const SizedBox(height: 8),
                  TextField(controller: apellidoCtrl, decoration: const InputDecoration(labelText: 'Apellido')),
                  const SizedBox(height: 8),
                  TextField(
                    controller: emailCtrl,
                    enabled: false,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      helperText: 'Para cambiarlo, escribe a soporte',
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: telefonoCtrl,
                    decoration: InputDecoration(labelText: 'Teléfono', errorText: errorTelefono),
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () {
                  final error = validarTelefono(telefonoCtrl.text);
                  if (error != null) {
                    setDialogState(() => errorTelefono = error);
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );

    final body = {
      'nombre': nombreCtrl.text.trim(),
      'apellido': apellidoCtrl.text.trim(),
      'telefono': telefonoCtrl.text.trim(),
    };
    // Liberar los controladores tras la animación de cierre del diálogo
    // (antes nunca se liberaban).
    Future<void>.delayed(const Duration(seconds: 1), () {
      nombreCtrl.dispose();
      apellidoCtrl.dispose();
      emailCtrl.dispose();
      telefonoCtrl.dispose();
    });
    if (result != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ApiClient.instance.updateProfile(body);
      await _loadProfile();
      messenger.showSnackBar(const SnackBar(content: Text('Perfil actualizado')));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: ${e.toString().replaceFirst("Exception: ", "")}')));
    }
  }

  Map<String, dynamic>? get _conductor => _profile?['conductor'] as Map<String, dynamic>?;

  void _showVehicleInfo() {
    final placa = _conductor?['placa'] as String? ?? 'No registrada';
    final tipo = _conductor?['tipoVehiculo'] as String? ?? 'No especificado';
    final capacidad = _conductor?['capacidad'] as String? ?? 'No especificada';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Vehículo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _infoRow('Placa', placa),
            _infoRow('Tipo', tipo.isEmpty ? tipo : tipo[0].toUpperCase() + tipo.substring(1)),
            _infoRow('Capacidad', capacidad),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: Colors.black54)),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColoresApp.fondo,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 20, color: ColoresApp.textoOscuro),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Perfil', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: ColoresApp.textoOscuro)),
        actions: [
          IconButton(
            icon: Icon(Icons.edit_outlined, size: 22, color: ColoresApp.textoOscuro),
            onPressed: _editInfo,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        const Text('No pudimos cargar tu perfil', style: TextStyle(fontSize: 16, color: Colors.black54)),
                        const SizedBox(height: 6),
                        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: ColoresApp.textoSecundario)),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() { _error = null; _loading = true; });
                            _loadProfile();
                          },
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
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
    final rating = (_conductor?['calificacion'] ?? 4.8).toString();
    final viajes = _conductor?['totalViajes'] ?? 129;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Row(
        children: [
          GestureDetector(
            onTap: _pickAvatar,
            child: Stack(
              children: [
                // Sin foto propia: iniciales (antes una foto de randomuser.me).
                MediaAvatar(
                  path: avatar,
                  name: nombre,
                  radius: 35,
                  backgroundColor: ColoresApp.azulOscuro,
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
                      color: ColoresApp.azulOscuro,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
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
                    nombre.isNotEmpty ? nombre : 'Sin nombre',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E)),
                  ),
                const SizedBox(height: 2),
                Text(email, style: TextStyle(fontSize: 12, color: ColoresApp.textoSecundario)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Color(0xFFFFC107), size: 18),
                    const SizedBox(width: 4),
                    Text(rating, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ColoresApp.textoOscuro)),
                    Text(' ($viajes viajes)', style: TextStyle(fontSize: 13, color: ColoresApp.textoSecundario)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItems() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          _buildMenuItem(Icons.person_outline, 'Información personal', _editInfo),
          _buildMenuItem(Icons.directions_car_outlined, 'Vehículos', _showVehicleInfo),
          _buildMenuItem(Icons.description_outlined, 'Documentos', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DocumentsScreen()))),
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
                Icon(icon, size: 22, color: ColoresApp.textoOscuro),
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
