import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../contracts/calificacion.dart' show etiquetaCalificacion;
import '../../contracts/validacion_usuario.dart';
import '../../services/api_client.dart';
import '../../services/api/http_client.dart' show ApiException;
import '../../services/driver_location_service.dart';
import '../../widgets/media_image.dart';
import '../shared/ui_compartida.dart' show ColoresApp, TarjetaBlanca, cifrasTabulares;
import '../user/auth_screen.dart';
import 'documents_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _loading = true;
  String? _error;
  // Contadores del historial (el servidor no da totales aparte), como en el perfil del cliente.
  int _envios = 0, _completados = 0, _cancelados = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadEstadisticas();
  }

  Future<void> _loadProfile() async {
    try {
      final data = await ApiClient.instance.getProfile();
      if (mounted) setState(() { _profile = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  Future<void> _loadEstadisticas() async {
    try {
      final viajes = await ApiClient.instance.getTripHistory(limit: 100);
      if (!mounted) return;
      setState(() {
        _envios = viajes.length;
        _completados = viajes.where((v) => v['estado'] == 'finalizado').length;
        _cancelados = viajes.where((v) => v['estado'] == 'cancelado').length;
      });
    } catch (_) {
      // Silencioso: las estadísticas son secundarias al perfil.
    }
  }

  Future<void> _logout() async {
    DriverLocationService.instance.stop();
    await ApiClient.instance.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (_) => false,
    );
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
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + MediaQuery.of(context).padding.bottom),
                  child: Column(
                    children: [
                      _buildProfileCard(),
                      const SizedBox(height: 20),
                      _buildStatsCard(),
                      const SizedBox(height: 12),
                      _buildMenuItems(),
                      const SizedBox(height: 12),
                      TarjetaBlanca(
                        padding: EdgeInsets.zero,
                        child: _buildMenuItem(Icons.logout_rounded, 'Cerrar sesión', _logout, color: ColoresApp.rojo, divisor: false),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildProfileCard() {
    final nombre = '${_profile?['nombre'] ?? ApiClient.instance.nombre ?? ''} ${_profile?['apellido'] ?? ''}'.trim();
    final email = _profile?['email'] as String? ?? ApiClient.instance.email ?? '';
    final telefono = (_profile?['telefono'] as String?)?.trim() ?? '';
    final avatar = _profile?['avatar'] as String?;
    final viajes = (_conductor?['totalViajes'] as num?)?.toInt() ?? 0;
    final rating = etiquetaCalificacion(_conductor?['calificacion'], totalViajes: viajes);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          GestureDetector(
            onTap: _pickAvatar,
            child: Stack(
              children: [
                // Sin foto propia: iniciales (antes una foto de randomuser.me).
                MediaAvatar(
                  path: avatar,
                  name: nombre,
                  radius: 44,
                  backgroundColor: ColoresApp.azulOscuro,
                  foregroundColor: Colors.white,
                  fontSize: 28,
                  border: Border.all(color: ColoresApp.borde, width: 2),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: ColoresApp.azul,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            nombre.isNotEmpty ? nombre : 'Sin nombre',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: ColoresApp.textoOscuro),
          ),
          const SizedBox(height: 4),
          Text(email, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: ColoresApp.textoSecundario)),
          if (telefono.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(telefono, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: ColoresApp.textoSecundario)),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star_rounded, color: ColoresApp.ambar, size: 20),
              const SizedBox(width: 4),
              Text(rating, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ColoresApp.textoOscuro, fontFeatures: cifrasTabulares)),
              Text(' ($viajes viajes)', style: const TextStyle(fontSize: 13, color: ColoresApp.textoSecundario)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    return TarjetaBlanca(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: IntrinsicHeight(
        child: Row(
          children: [
            _stat('$_envios', 'Envíos', ColoresApp.textoOscuro),
            const VerticalDivider(width: 1, thickness: 1, color: ColoresApp.divisor),
            _stat('$_completados', 'Completados', ColoresApp.verde),
            const VerticalDivider(width: 1, thickness: 1, color: ColoresApp.divisor),
            _stat('$_cancelados', 'Cancelados', ColoresApp.rojo),
          ],
        ),
      ),
    );
  }

  Widget _stat(String valor, String etiqueta, Color color) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(valor, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: color, fontFeatures: cifrasTabulares)),
          const SizedBox(height: 2),
          Text(etiqueta, style: const TextStyle(fontSize: 12, color: ColoresApp.textoSecundario)),
        ],
      ),
    );
  }

  Widget _buildMenuItems() {
    return TarjetaBlanca(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _buildMenuItem(Icons.person_outline, 'Información personal', _editInfo),
          _buildMenuItem(Icons.directions_car_outlined, 'Vehículo', _showVehicleInfo),
          _buildMenuItem(Icons.description_outlined, 'Documentos', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DocumentsScreen()))),
          _buildMenuItem(Icons.settings_outlined, 'Ajustes', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())), divisor: false),
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String label, VoidCallback? onTap, {Color color = ColoresApp.textoOscuro, bool divisor = true}) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(icon, size: 22, color: color),
                const SizedBox(width: 14),
                Expanded(child: Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: color))),
                const Icon(Icons.chevron_right, color: ColoresApp.chevron),
              ],
            ),
          ),
        ),
        if (divisor) const Divider(height: 1, thickness: 1, color: ColoresApp.divisor),
      ],
    );
  }
}
