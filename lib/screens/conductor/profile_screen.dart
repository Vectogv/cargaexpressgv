import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LengthLimitingTextInputFormatter;
import 'package:image_picker/image_picker.dart';
import '../../contracts/calificacion.dart' show etiquetaCalificacion;
import '../../contracts/validacion_usuario.dart';
import '../../services/api_client.dart';
import '../../services/api/http_client.dart' show ApiException;
import '../../services/driver_location_service.dart';
import '../../widgets/media_image.dart';
import '../shared/ui_compartida.dart' show BotonPrincipal, ColoresApp, TarjetaBlanca, cifrasTabulares;
import '../user/auth_estilos.dart' show AvisoErrorAuth;
import '../user/auth_screen.dart';
import 'documents_screen.dart';
import 'grupo_conductores_screen.dart';
import 'offers_screen.dart';
import 'settings_screen.dart';
import 'support_screen.dart';

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

  /// Pantalla completa (como el cliente); guarda por su cuenta y devuelve true
  /// si hubo cambios que recargar.
  Future<void> _editInfo() async {
    final guardado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => _EditarPerfilConductorScreen(perfil: _profile ?? const {})),
    );
    if (guardado != true || !mounted) return;
    await _loadProfile();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perfil actualizado')));
  }

  Map<String, dynamic>? get _conductor => _profile?['conductor'] as Map<String, dynamic>?;

  void _showVehicleInfo() {
    final placa = _conductor?['placa'] as String? ?? 'No registrada';
    final tipo = _conductor?['tipoVehiculo'] as String? ?? 'No especificado';
    final capacidad = _conductor?['capacidad'] as String? ?? 'No especificada';
    final foto = _conductor?['fotoVehiculo'] as String?;

    // Hoja inferior en vez del diálogo chico: la foto necesita ancho.
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Vehículo', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: ColoresApp.textoOscuro)),
              const SizedBox(height: 12),
              // Sin foto subida, MediaImage muestra su placeholder por defecto.
              MediaImage(path: foto, height: 180, width: double.infinity, fit: BoxFit.cover, borderRadius: BorderRadius.circular(12)),
              const SizedBox(height: 12),
              _infoRow('Placa', placa),
              _infoRow('Tipo', tipo.isEmpty ? tipo : tipo[0].toUpperCase() + tipo.substring(1)),
              _infoRow('Capacidad', capacidad),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
              ),
            ],
          ),
        ),
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
          const SizedBox(width: 12),
          Flexible(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
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
          // Mis ofertas y Soporte vivían solo en el menú lateral del inicio (ya quitado).
          _buildMenuItem(Icons.local_offer_outlined, 'Mis ofertas', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OffersScreen()))),
          _buildMenuItem(Icons.groups_outlined, 'Grupo de conductores', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GrupoConductoresScreen()))),
          _buildMenuItem(Icons.headset_mic_outlined, 'Soporte', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportScreen()))),
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

/// Edición del perfil del conductor, calcada de la del cliente
/// (`cliente/perfil_screen.dart`, `_EditarPerfilScreen`) pero sin portada y
/// con el contacto de emergencia obligatorio: el SOS del conductor necesita a
/// quién llamar. Guarda por su cuenta (PUT /api/users/profile) y devuelve true
/// si guardó, null si se canceló.
class _EditarPerfilConductorScreen extends StatefulWidget {
  final Map<String, dynamic> perfil;
  const _EditarPerfilConductorScreen({required this.perfil});

  @override
  State<_EditarPerfilConductorScreen> createState() => _EditarPerfilConductorScreenState();
}

class _EditarPerfilConductorScreenState extends State<_EditarPerfilConductorScreen> {
  late final _nombre = _ctrl('nombre');
  late final _apellido = _ctrl('apellido');
  late final _email = _ctrl('email');
  late final _telefono = _ctrl('telefono');
  late final _contactoNombre = _ctrl('contactoEmergenciaNombre');
  late final _contactoTelefono = _ctrl('contactoEmergenciaTelefono');

  String? _errorTelefono;
  String? _errorContactoNombre;
  String? _errorContactoTelefono;
  String? _errorGeneral;
  bool _guardando = false;

  TextEditingController _ctrl(String campo) =>
      TextEditingController(text: widget.perfil[campo]?.toString() ?? '');

  @override
  void dispose() {
    for (final c in [_nombre, _apellido, _email, _telefono, _contactoNombre, _contactoTelefono]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _seccion(String titulo, {String? detalle, required List<Widget> hijos}) => Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(titulo, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: ColoresApp.textoOscuro)),
            if (detalle != null) ...[
              const SizedBox(height: 2),
              Text(detalle, style: const TextStyle(fontSize: 13, color: ColoresApp.textoSecundario)),
            ],
            const SizedBox(height: 12),
            ...hijos,
          ],
        ),
      );

  Widget _campo(TextEditingController c, String label, int max,
      {TextInputType tipo = TextInputType.text, String? error, bool enabled = true, String? ayuda}) {
    OutlineInputBorder borde(Color color, [double ancho = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: color, width: ancho));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: ColoresApp.etiquetaCampo)),
        const SizedBox(height: 6),
        TextField(
          key: ValueKey('campo_$label'),
          controller: c,
          keyboardType: tipo,
          enabled: enabled && !_guardando,
          inputFormatters: [LengthLimitingTextInputFormatter(max)],
          style: TextStyle(fontSize: 15, color: enabled ? ColoresApp.textoOscuro : ColoresApp.textoSecundario),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: enabled ? Colors.white : ColoresApp.fondo,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            enabledBorder: borde(ColoresApp.bordeCampo),
            disabledBorder: borde(ColoresApp.borde),
            focusedBorder: borde(ColoresApp.azul, 2),
            errorBorder: borde(ColoresApp.rojoSesion),
            focusedErrorBorder: borde(ColoresApp.rojoSesion, 2),
            errorText: error,
            helperText: ayuda,
            helperStyle: const TextStyle(fontSize: 12, color: ColoresApp.textoSecundario),
          ),
        ),
      ],
    );
  }

  Future<void> _guardar() async {
    final errorTelefono = validarTelefono(_telefono.text);
    final errorContactoNombre = _contactoNombre.text.trim().isEmpty ? 'El nombre del contacto es obligatorio' : null;
    final errorContactoTelefono = validarTelefono(_contactoTelefono.text);
    if (errorTelefono != null || errorContactoNombre != null || errorContactoTelefono != null) {
      setState(() {
        _errorTelefono = errorTelefono;
        _errorContactoNombre = errorContactoNombre;
        _errorContactoTelefono = errorContactoTelefono;
      });
      return;
    }
    setState(() {
      _guardando = true;
      _errorGeneral = null;
      _errorTelefono = null;
      _errorContactoNombre = null;
      _errorContactoTelefono = null;
    });
    try {
      await ApiClient.instance.updateProfile(cuerpoActualizacionPerfil(
        nombre: _nombre.text,
        apellido: _apellido.text,
        telefono: _telefono.text,
        contactoNombre: _contactoNombre.text,
        contactoTelefono: _contactoTelefono.text,
      ));
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      setState(() {
        _guardando = false;
        _errorGeneral = e.message;
      });
    } catch (e) {
      setState(() {
        _guardando = false;
        _errorGeneral = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_guardando,
      child: Scaffold(
        backgroundColor: ColoresApp.fondo,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          foregroundColor: ColoresApp.textoOscuro,
          elevation: 0,
          scrolledUnderElevation: 0,
          shape: const Border(bottom: BorderSide(color: ColoresApp.borde)),
          title: const Text('Editar perfil', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          children: [
            _seccion('Datos personales', hijos: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _campo(_nombre, 'Nombre', LimitesUsuario.nombre)),
                  const SizedBox(width: 12),
                  Expanded(child: _campo(_apellido, 'Apellido', LimitesUsuario.apellido)),
                ],
              ),
            ]),
            _seccion('Contacto', hijos: [
              _campo(_email, 'Correo', LimitesUsuario.email,
                  tipo: TextInputType.emailAddress, enabled: false, ayuda: 'Para cambiarlo, escribe a soporte.'),
              const SizedBox(height: 14),
              _campo(_telefono, 'Teléfono', LimitesUsuario.telefono, tipo: TextInputType.phone, error: _errorTelefono),
            ]),
            _seccion('Contacto de emergencia', detalle: 'Lo llamamos si activas el SOS durante un viaje.', hijos: [
              _campo(_contactoNombre, 'Nombre del contacto', LimitesUsuario.contactoNombre, error: _errorContactoNombre),
              const SizedBox(height: 14),
              _campo(_contactoTelefono, 'Teléfono del contacto', LimitesUsuario.contactoTelefono,
                  tipo: TextInputType.phone, error: _errorContactoTelefono),
            ]),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: ColoresApp.borde)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_errorGeneral != null) ...[
                    AvisoErrorAuth(mensaje: _errorGeneral!),
                    const SizedBox(height: 10),
                  ],
                  BotonPrincipal(
                    texto: _guardando ? 'Guardando…' : 'Guardar cambios',
                    onPressed: _guardando ? null : _guardar,
                    color: ColoresApp.azul,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
