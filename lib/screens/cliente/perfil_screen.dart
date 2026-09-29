import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../contracts/calificacion.dart';
import '../../contracts/validacion_usuario.dart';
import '../../services/api_client.dart';
import '../../services/api/http_client.dart' show ApiException;
import '../../services/api/payment_service.dart';
import '../../widgets/media_image.dart';
import '../shared/ui_compartida.dart';
import '../user/auth_estilos.dart';
import '../user/auth_screen.dart';
import 'ajustes_screen.dart';
import 'pagos_screen.dart';

/// Color de acento del avatar, elegido por el cliente en "Editar perfil" y
/// guardado solo en el celular (no hay campo para esto en el servidor).
const _claveColorPerfil = 'color_perfil_cliente';
const List<Color> coloresPerfilDisponibles = [
  ColoresApp.azul,
  ColoresApp.verde,
  ColoresApp.naranja,
  ColoresApp.rojo,
  ColoresApp.ambar,
  ColoresApp.azulMarino,
];

/// Cuerpo de PUT /api/users/profile (app/validators/profile.ts): nombre y
/// apellido vacíos no se envían (no se borran); teléfono y contacto de
/// emergencia vacíos se envían como null (el backend los acepta nulos). El
/// email no se envía: es el usuario de inicio de sesión y no se edita aquí.
Map<String, dynamic> cuerpoActualizacionPerfil({
  required String nombre,
  required String apellido,
  required String telefono,
  required String contactoNombre,
  required String contactoTelefono,
}) {
  String? opcional(String v) => v.trim().isEmpty ? null : v.trim();
  return {
    if (nombre.trim().isNotEmpty) 'nombre': nombre.trim(),
    if (apellido.trim().isNotEmpty) 'apellido': apellido.trim(),
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
  int _totalViajes = 0;
  int _completados = 0;
  int _cancelados = 0;
  // Pagos sólo aparece si hay deuda (GET /api/payments), igual que en el inicio.
  bool _tieneDeuda = false;
  bool _suspendidoPorPago = false;
  Color _colorPerfil = ColoresApp.azul;

  static const Color _textDark = Color(0xFF1A1A2E);
  static const Color _textGrey = Color(0xFF757575);
  static const Color _bgLight = Color(0xFFF5F7FA);
  static const Color _white = Colors.white;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadDeuda();
    _cargarColorPerfil();
  }

  Future<void> _cargarColorPerfil() async {
    final prefs = await SharedPreferences.getInstance();
    final valor = prefs.getInt(_claveColorPerfil);
    if (mounted && valor != null) {
      setState(() => _colorPerfil = Color(valor));
    }
  }

  /// Si falla, Pagos queda oculto (no se bloquea el perfil).
  Future<void> _loadDeuda() async {
    try {
      final info = await PaymentService.getDebtInfo();
      if (mounted) {
        setState(() {
          _tieneDeuda = tieneDeudaPendiente(info);
          _suspendidoPorPago = cuentaSuspendidaPorPago(info);
        });
      }
    } catch (_) {}
  }

  void _abrirPagos() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const PagosScreen())).then((_) {
      if (mounted) _loadDeuda();
    });
  }

  Future<void> _loadProfile() async {
    try {
      // Envíos/Completados/Cancelados salen de contar el historial: el
      // servidor no expone esos totales por separado.
      final resultados = await Future.wait([
        ApiClient.instance.getProfile(),
        ApiClient.instance.getTripHistory(limit: 100),
      ]);
      final data = resultados[0] as Map<String, dynamic>;
      final viajes = resultados[1] as List<Map<String, dynamic>>;
      if (mounted) {
        setState(() {
          _profile = data;
          _totalViajes = viajes.length;
          _completados = viajes.where((v) => v['estado'] == 'finalizado').length;
          _cancelados = viajes.where((v) => v['estado'] == 'cancelado').length;
          _loading = false;
        });
      }
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

  /// El diálogo guarda por su cuenta (así puede mostrar "Guardando..." y un
  /// error sin perder lo escrito) y devuelve el color elegido si tuvo éxito,
  /// o null si se canceló o falló.
  Future<void> _editInfo() async {
    final color = await showDialog<Color>(
      context: context,
      builder: (_) => _EditarPerfilDialog(perfil: _profile ?? const {}, colorInicial: _colorPerfil),
    );
    if (color == null || !mounted) return;
    setState(() => _colorPerfil = color);
    await _loadProfile();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perfil actualizado')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _buildError()
                      : RefreshIndicator(
                          onRefresh: () => Future.wait([_loadProfile(), _loadDeuda()]),
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildStatsCard(),
                                const SizedBox(height: 16),
                                _seccionTitulo('Calificación'),
                                _buildCalificacionCard(),
                                const SizedBox(height: 16),
                                _seccionTitulo('Preferencias'),
                                _buildPreferenciasCard(),
                                const SizedBox(height: 16),
                                _seccionTitulo('Cuenta'),
                                _buildCuentaCard(),
                              ],
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text('No pudimos cargar tu perfil', style: TextStyle(fontSize: 16, color: Colors.black54)),
            const SizedBox(height: 6),
            Text(_error!, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: _textGrey)),
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
    );
  }

  Widget _buildHeader() {
    final nombre = '${_profile?['nombre'] ?? ApiClient.instance.nombre ?? ''} ${_profile?['apellido'] ?? ''}'.trim();
    final email = _profile?['email'] as String? ?? ApiClient.instance.email ?? '';
    final avatar = _profile?['avatar'] as String?;
    final telefono = _profile?['telefono'] as String?;

    return Container(
      color: _white,
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        children: [
          SizedBox(
            height: 56,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: _textDark),
                  onPressed: () => Navigator.pop(context),
                ),
                const Text('Mi perfil', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _textDark)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20, color: _textDark),
                  onPressed: _editInfo,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: _pickAvatar,
                  child: Stack(
                    children: [
                      MediaAvatar(
                        path: avatar,
                        name: nombre,
                        radius: 32,
                        backgroundColor: _colorPerfil,
                        foregroundColor: _white,
                        fontSize: 20,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: _colorPerfil,
                            shape: BoxShape.circle,
                            border: Border.all(color: _white, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre.isNotEmpty ? nombre : 'Cliente',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _textDark),
                      ),
                      const SizedBox(height: 3),
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
          ),
        ],
      ),
    );
  }

  Widget _seccionTitulo(String texto) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 4),
        child: Text(
          texto.toUpperCase(),
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _textGrey, letterSpacing: 0.4),
        ),
      );

  Widget _buildStatsCard() {
    return TarjetaBlanca(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      child: Row(
        children: [
          Expanded(child: _stat(Icons.inventory_2_outlined, ColoresApp.azul, '$_totalViajes', 'Envíos')),
          Container(width: 1, height: 40, color: ColoresApp.borde),
          Expanded(child: _stat(Icons.check_circle_outline, ColoresApp.verde, '$_completados', 'Completados')),
          Container(width: 1, height: 40, color: ColoresApp.borde),
          Expanded(child: _stat(Icons.close, ColoresApp.rojo, '$_cancelados', 'Cancelados')),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, Color color, String valor, String etiqueta) {
    return Column(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(height: 6),
        Text(valor, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _textDark)),
        const SizedBox(height: 2),
        Text(etiqueta, style: TextStyle(fontSize: 11, color: _textGrey)),
      ],
    );
  }

  /// Calificación real: promedio que el servidor calcula en cada viaje que
  /// un conductor califica a este cliente (`perfil.calificacion`,
  /// POST /api/trips/:id/rate). "Nuevo" mientras no tenga viajes calificados.
  Widget _buildCalificacionCard() {
    final etiqueta = etiquetaCalificacion(_profile?['calificacion'], totalViajes: _totalViajes);
    final esNuevo = etiqueta == 'Nuevo';
    return TarjetaBlanca(
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(color: Color(0xFFFFF7E6), shape: BoxShape.circle),
            child: const Icon(Icons.star_rounded, size: 18, color: Color(0xFFF59E0B)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Calificación como cliente', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _textDark)),
                const SizedBox(height: 2),
                Text(
                  esNuevo ? 'Aún sin calificaciones de conductores' : 'Promedio de tus viajes',
                  style: TextStyle(fontSize: 12, color: _textGrey),
                ),
              ],
            ),
          ),
          Text(etiqueta, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: esNuevo ? _textGrey : _textDark)),
        ],
      ),
    );
  }

  Widget _buildPreferenciasCard() {
    return TarjetaBlanca(
      padding: EdgeInsets.zero,
      child: _filaValor(Icons.language, 'Idioma de la app', 'Español'),
    );
  }

  Widget _filaValor(IconData icon, String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Icon(icon, size: 20, color: _textDark),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500))),
          Text(valor, style: TextStyle(fontSize: 14, color: _textGrey)),
        ],
      ),
    );
  }

  Widget _buildCuentaCard() {
    return TarjetaBlanca(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _buildMenuItem(Icons.person_outline, 'Información personal', _editInfo),
          if (_tieneDeuda)
            _buildMenuItem(Icons.payments_outlined, 'Pagos', _abrirPagos,
                destacado: _suspendidoPorPago ? 'Pendiente' : null),
          _buildMenuItem(
            Icons.tune,
            'Ajustes',
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AjustesScreen())),
          ),
          _buildMenuItem(Icons.logout, 'Cerrar sesión', _saliendo ? null : _logout, divisor: false),
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String label, VoidCallback? onTap,
      {bool divisor = true, String? destacado}) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Icon(icon, size: 22, color: destacado != null ? const Color(0xFFB91C1C) : _textDark),
                const SizedBox(width: 14),
                Expanded(child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500))),
                if (destacado != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(20)),
                    child: Text(destacado,
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFFB91C1C))),
                  ),
                  const SizedBox(width: 8),
                ],
                Icon(Icons.chevron_right, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
        if (divisor) const Divider(height: 1, indent: 56, endIndent: 0),
      ],
    );
  }
}

/// Formulario de edición del perfil. Guarda por su cuenta (PUT
/// /api/users/profile) y devuelve el color de acento elegido si tuvo éxito,
/// o null si se canceló.
class _EditarPerfilDialog extends StatefulWidget {
  final Map<String, dynamic> perfil;
  final Color colorInicial;
  const _EditarPerfilDialog({required this.perfil, required this.colorInicial});

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

  late Color _color = widget.colorInicial;
  String? _errorTelefono;
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

  Widget _tituloSeccion(String texto) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          texto.toUpperCase(),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AuthColores.gris, letterSpacing: 0.4),
        ),
      );

  Widget _selectorColor() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AuthColores.campo,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AuthColores.borde),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MediaAvatar(path: null, name: '${_nombre.text} ${_apellido.text}', radius: 22, backgroundColor: _color, foregroundColor: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Elige tu estilo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AuthColores.texto)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: coloresPerfilDisponibles.map((c) {
                    final seleccionado = c.toARGB32() == _color.toARGB32();
                    return GestureDetector(
                      onTap: _guardando ? null : () => setState(() => _color = c),
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(color: seleccionado ? AuthColores.texto : Colors.transparent, width: 2),
                        ),
                        child: seleccionado ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _campo(TextEditingController c, String label, int max, IconData icono,
          {TextInputType tipo = TextInputType.text, String? error, bool enabled = true, String? ayuda}) =>
      TextField(
        controller: c,
        keyboardType: tipo,
        enabled: enabled && !_guardando,
        inputFormatters: [LengthLimitingTextInputFormatter(max)],
        decoration: decoracionCampoAuth(label: label, icono: icono, ayuda: ayuda).copyWith(errorText: error),
      );

  Future<void> _guardar() async {
    final errorTelefono = validarTelefono(_telefono.text);
    final errorContacto = validarTelefono(_contactoTelefono.text, opcional: true);
    if (errorTelefono != null || errorContacto != null) {
      setState(() {
        _errorTelefono = errorTelefono;
        _errorContactoTelefono = errorContacto;
      });
      return;
    }
    setState(() {
      _guardando = true;
      _errorGeneral = null;
    });
    try {
      await ApiClient.instance.updateProfile(cuerpoActualizacionPerfil(
        nombre: _nombre.text,
        apellido: _apellido.text,
        telefono: _telefono.text,
        contactoNombre: _contactoNombre.text,
        contactoTelefono: _contactoTelefono.text,
      ));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_claveColorPerfil, _color.toARGB32());
      if (!mounted) return;
      Navigator.pop(context, _color);
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
      child: AlertDialog(
        title: const Text('Editar perfil'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _selectorColor(),
              const SizedBox(height: 18),
              _tituloSeccion('Datos personales'),
              _campo(_nombre, 'Nombre', LimitesUsuario.nombre, Icons.badge_outlined),
              const SizedBox(height: 10),
              _campo(_apellido, 'Apellido', LimitesUsuario.apellido, Icons.badge_outlined),
              const SizedBox(height: 18),
              _tituloSeccion('Contacto'),
              _campo(_email, 'Email', LimitesUsuario.email, Icons.email_outlined,
                  tipo: TextInputType.emailAddress, enabled: false, ayuda: 'Para cambiarlo, escribe a soporte'),
              const SizedBox(height: 10),
              _campo(_telefono, 'Teléfono', LimitesUsuario.telefono, Icons.phone_outlined,
                  tipo: TextInputType.phone, error: _errorTelefono),
              const SizedBox(height: 18),
              _tituloSeccion('Contacto de emergencia'),
              _campo(_contactoNombre, 'Contacto de emergencia', LimitesUsuario.contactoNombre, Icons.contact_phone_outlined),
              const SizedBox(height: 10),
              _campo(_contactoTelefono, 'Teléfono del contacto', LimitesUsuario.contactoTelefono, Icons.phone_outlined,
                  tipo: TextInputType.phone, error: _errorContactoTelefono),
              if (_errorGeneral != null) ...[
                const SizedBox(height: 14),
                AvisoErrorAuth(mensaje: _errorGeneral!),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: _guardando ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: _guardando ? null : _guardar,
            child: _guardando
                ? const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                      SizedBox(width: 10),
                      Text('Guardando...'),
                    ],
                  )
                : const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}
