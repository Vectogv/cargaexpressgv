import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../contracts/validacion_usuario.dart';
import '../../services/api_client.dart';
import '../../services/api/http_client.dart';
import '../home_by_role.dart';
import 'auth_estilos.dart';
import 'google_login.dart';
import 'login_screen.dart';
import 'registro_conductor/registro_conductor_screen.dart';

/// Registro del cliente. El conductor se registra con el asistente
/// [RegistroConductorScreen]; sin flavor (pruebas) la tarjeta "Conductor" lo abre.
class RegisterScreen extends StatefulWidget {
  /// Datos de Google (404 CUENTA_NO_EXISTE) y su idToken: el formulario llega
  /// prellenado y se registra con `idToken` en vez de contraseña.
  final Map<String, dynamic>? google;
  final String? idToken;
  const RegisterScreen({super.key, this.google, this.idToken});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  // Cada app registra un solo rol; sin flavor (pruebas) se elige con las tarjetas.
  static final bool _elegirRol = !esAppCliente && !esAppConductor;
  int get _sinPaso => _elegirRol ? 0 : 1;
  int get _totalPasos => 2 - _sinPaso;
  bool _loading = false;
  bool _obscure = true;
  bool _intentado = false;
  bool _formInvalido = false;
  String? _error;
  Map<String, dynamic>? _google;
  String? _idToken;

  final _nombreCtrl = TextEditingController();
  final _apellidoCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _edadCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.google != null) _usarGoogle(widget.google!, widget.idToken);
  }

  void _usarGoogle(Map<String, dynamic> google, String? idToken) {
    setState(() {
      _google = google;
      _idToken = idToken;
      _nombreCtrl.text = (google['nombre'] ?? '').toString();
      _apellidoCtrl.text = (google['apellido'] ?? '').toString();
      _emailCtrl.text = (google['email'] ?? '').toString();
    });
  }

  @override
  void dispose() {
    for (final c in [_nombreCtrl, _apellidoCtrl, _emailCtrl, _passCtrl, _telefonoCtrl, _edadCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Validaciones (mismas reglas que app/validators/auth.ts) ──

  static String? _obligatorio(String? v) =>
      (v ?? '').trim().isEmpty ? 'Este campo es obligatorio' : null;

  static String? _validarEmail(String? v) =>
      (v ?? '').trim().isEmpty ? 'Ingresa tu correo electrónico' : validarEmail(v!);

  static String? _validarPassword(String? v) =>
      (v ?? '').isEmpty ? 'Crea una contraseña' : validarPasswordRegistro(v!);

  static String? _validarEdad(String? v) {
    final edad = int.tryParse((v ?? '').trim());
    if (edad != null && edad < LimitesUsuario.edadMin) {
      return 'Debes ser mayor de 18 años para registrarte';
    }
    return validarEdad(v ?? '');
  }

  Future<void> _register() async {
    FocusScope.of(context).unfocus();
    final valido = _formKey.currentState?.validate() ?? false;
    setState(() {
      _intentado = true;
      _formInvalido = !valido;
      _error = null;
    });
    if (!valido) return;

    setState(() => _loading = true);

    final Map<String, dynamic> body = {
      'nombre': _nombreCtrl.text.trim(),
      'apellido': _apellidoCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      if (_google == null) 'password': _passCtrl.text else 'idToken': _idToken,
      'rol': 'cliente',
    };
    if (_telefonoCtrl.text.trim().isNotEmpty) {
      body['telefono'] = _telefonoCtrl.text.trim();
    }
    body['edad'] = int.parse(_edadCtrl.text.trim());

    try {
      final auth = await ApiClient.instance.register(body);
      if (!mounted) {
        // La pantalla se cerró mientras se registraba: no dejar sesión huérfana.
        await ApiClient.instance.logout();
        return;
      }
      final home = homeDestinoFor(rol: auth.rol, esModerador: auth.esModerador);
      if (errorDeDestino(home) != null) {
        // Rol sin pantalla en la app: cerrar la sesión que dejó el registro.
        await ApiClient.instance.logout();
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
        return;
      }
      // El registro ya autentica (guarda tokens y perfil): ir directo al
      // home del rol en lugar de pedir un segundo login.
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cuenta creada exitosamente')));
      abrirInicioComoRaiz(context, homeScreenFor(home));
    } catch (e) {
      final msg = e is ApiException ? e.message : e.toString().replaceFirst('Exception: ', '');
      if (mounted) setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthColores.fondo,
      appBar: AppBar(
        backgroundColor: AuthColores.fondo,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: AuthColores.texto),
        title: const MarcaCargaExpress(tamano: 17),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          autovalidateMode: _intentado ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Crea tu cuenta',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AuthColores.texto, letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _elegirRol ? 'Solo te toma un minuto. Elige cómo usarás CargaExpress.' : 'Solo te toma un minuto.',
                      style: const TextStyle(fontSize: 15, color: AuthColores.gris, height: 1.35),
                    ),
                    const SizedBox(height: 22),
                    if (_elegirRol) ...[
                    _TituloSeccion(paso: 1, titulo: 'Tipo de cuenta', total: _totalPasos),
                    const SizedBox(height: 12),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _TarjetaRol(
                              key: const Key('rol_cliente'),
                              icono: Icons.inventory_2_outlined,
                              titulo: 'Cliente',
                              descripcion: 'Quiero enviar carga',
                              seleccionado: true,
                              onTap: () {},
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _TarjetaRol(
                              key: const Key('rol_conductor'),
                              icono: Icons.local_shipping_outlined,
                              titulo: 'Conductor',
                              descripcion: 'Quiero transportar carga',
                              seleccionado: false,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const RegistroConductorScreen()),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ],
                    if (_google == null) ...[
                      const SizedBox(height: 16),
                      BotonGoogleAuth(deshabilitado: _loading, onSinCuenta: _usarGoogle),
                      const SeparadorAuth(texto: 'o con tu correo'),
                    ] else
                      const SizedBox(height: 22),
                    _TituloSeccion(paso: 2 - _sinPaso, titulo: 'Datos personales', total: _totalPasos),
                    const SizedBox(height: 12),
                    if (_google != null) ...[
                      const Text(
                        'Te registras con tu cuenta de Google. Solo faltan unos datos.',
                        style: TextStyle(fontSize: 13.5, color: AuthColores.gris, height: 1.35),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TarjetaAuth(
                      child: AutofillGroup(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _campo(
                              controller: _nombreCtrl,
                              label: 'Nombre',
                              icono: Icons.person_outline_rounded,
                              maxLength: LimitesUsuario.nombre,
                              validator: _obligatorio,
                              capitalizacion: TextCapitalization.words,
                              autofill: AutofillHints.givenName,
                            ),
                            _campo(
                              controller: _apellidoCtrl,
                              label: 'Apellido',
                              icono: Icons.badge_outlined,
                              maxLength: LimitesUsuario.apellido,
                              validator: _obligatorio,
                              capitalizacion: TextCapitalization.words,
                              autofill: AutofillHints.familyName,
                            ),
                            _campo(
                              controller: _emailCtrl,
                              label: 'Correo electrónico',
                              icono: Icons.mail_outline_rounded,
                              teclado: TextInputType.emailAddress,
                              maxLength: LimitesUsuario.email,
                              validator: _validarEmail,
                              autofill: AutofillHints.email,
                              habilitado: _google == null,
                              ayuda: _google == null ? null : 'Es el de tu cuenta de Google',
                            ),
                            if (_google == null)
                              _campo(
                                controller: _passCtrl,
                                label: 'Contraseña',
                                icono: Icons.lock_outline_rounded,
                                ayuda: 'Entre ${LimitesUsuario.passwordMin} y ${LimitesUsuario.passwordMax} caracteres',
                                obscure: _obscure,
                                maxLength: LimitesUsuario.passwordMax,
                                validator: _validarPassword,
                                autofill: AutofillHints.newPassword,
                                sufijo: IconButton(
                                  tooltip: _obscure ? 'Mostrar contraseña' : 'Ocultar contraseña',
                                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                                  onPressed: () => setState(() => _obscure = !_obscure),
                                ),
                              ),
                            _campo(
                              controller: _telefonoCtrl,
                              label: 'Teléfono (opcional)',
                              icono: Icons.phone_outlined,
                              teclado: TextInputType.phone,
                              maxLength: LimitesUsuario.telefono,
                              autofill: AutofillHints.telephoneNumber,
                              validator: (v) => validarTelefono(v ?? '', opcional: true),
                            ),
                            _campo(
                              controller: _edadCtrl,
                              label: 'Edad',
                              icono: Icons.cake_outlined,
                              ayuda: 'Debes ser mayor de edad',
                              teclado: TextInputType.number,
                              maxLength: 3,
                              soloDigitos: true,
                              validator: _validarEdad,
                              ultimo: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    if (_error != null) ...[
                      AvisoErrorAuth(mensaje: _error!),
                      const SizedBox(height: 14),
                    ] else if (_formInvalido) ...[
                      const AvisoErrorAuth(mensaje: 'Revisa los campos marcados en rojo.'),
                      const SizedBox(height: 14),
                    ],
                    BotonPrincipalAuth(
                      key: const Key('btn_registro'),
                      texto: 'Crear cuenta',
                      textoCargando: 'Creando cuenta...',
                      cargando: _loading,
                      onPressed: _register,
                    ),
                    const SizedBox(height: 12),
                    EnlaceAuth(
                      botonKey: const Key('link_login'),
                      pregunta: '¿Ya tienes cuenta?',
                      accion: 'Inicia sesión',
                      onTap: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _campo({
    required TextEditingController controller,
    required String label,
    required IconData icono,
    String? ayuda,
    TextInputType teclado = TextInputType.text,
    bool obscure = false,
    Widget? sufijo,
    TextCapitalization capitalizacion = TextCapitalization.none,
    int? maxLength,
    bool soloDigitos = false,
    String? Function(String?)? validator,
    String? autofill,
    bool ultimo = false,
    bool habilitado = true,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: ultimo ? 0 : 14),
      child: TextFormField(
        controller: controller,
        enabled: habilitado,
        // Límite del backend (app/validators/auth.ts), sin contador visible.
        inputFormatters: [
          if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
          if (soloDigitos) FilteringTextInputFormatter.digitsOnly,
        ],
        keyboardType: teclado,
        obscureText: obscure,
        autocorrect: !obscure && teclado != TextInputType.emailAddress,
        enableSuggestions: !obscure,
        textCapitalization: capitalizacion,
        textInputAction: ultimo ? TextInputAction.done : TextInputAction.next,
        autofillHints: autofill == null ? null : [autofill],
        validator: validator,
        decoration: decoracionCampoAuth(label: label, icono: icono, ayuda: ayuda, sufijo: sufijo),
      ),
    );
  }
}

class _TituloSeccion extends StatelessWidget {
  final int paso;
  final int total;
  final String titulo;
  const _TituloSeccion({required this.paso, required this.total, required this.titulo});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      label: 'Paso $paso de $total: $titulo',
      excludeSemantics: true,
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AuthColores.primario, shape: BoxShape.circle),
            child: Text('$paso', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              titulo,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AuthColores.texto),
            ),
          ),
          Text('$paso/$total', style: const TextStyle(fontSize: 12.5, color: AuthColores.gris, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _TarjetaRol extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String descripcion;
  final bool seleccionado;
  final VoidCallback onTap;
  const _TarjetaRol({
    super.key,
    required this.icono,
    required this.titulo,
    required this.descripcion,
    required this.seleccionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: seleccionado,
      child: Material(
        color: seleccionado ? const Color(0xFFEFF4FF) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: seleccionado ? AuthColores.primario : AuthColores.borde,
                width: seleccionado ? 2 : 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: seleccionado ? AuthColores.primario : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icono, size: 22, color: seleccionado ? Colors.white : AuthColores.gris),
                    ),
                    const Spacer(),
                    Icon(
                      seleccionado ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      size: 22,
                      color: seleccionado ? AuthColores.primario : const Color(0xFFBFC5CD),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  titulo,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AuthColores.texto),
                ),
                const SizedBox(height: 2),
                Text(
                  descripcion,
                  style: const TextStyle(fontSize: 13, color: AuthColores.gris, height: 1.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
