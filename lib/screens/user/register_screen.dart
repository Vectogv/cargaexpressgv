import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../contracts/validacion_usuario.dart';
import '../../services/api_client.dart';
import '../../services/api/http_client.dart';
import '../home_by_role.dart';
import 'auth_estilos.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  String _rol = 'cliente';
  bool _loading = false;
  bool _obscure = true;
  bool _intentado = false;
  bool _formInvalido = false;
  String? _error;

  final _nombreCtrl = TextEditingController();
  final _apellidoCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _edadCtrl = TextEditingController();

  final _cedulaCtrl = TextEditingController();
  final _placaCtrl = TextEditingController();
  final _capacidadCtrl = TextEditingController();
  final _ciudadCtrl = TextEditingController();
  String _tipoVehiculo = 'Motocicleta';

  static const List<String> _tiposVehiculo = [
    'Motocicleta',
    'Sedan',
    'Camioneta',
    'Camion',
    'Furgon',
  ];

  bool get _esConductor => _rol == 'conductor';

  @override
  void dispose() {
    for (final c in [
      _nombreCtrl, _apellidoCtrl, _emailCtrl, _passCtrl, _telefonoCtrl,
      _edadCtrl, _cedulaCtrl, _placaCtrl, _capacidadCtrl, _ciudadCtrl,
    ]) {
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
      'password': _passCtrl.text,
      'rol': _rol,
    };
    if (_telefonoCtrl.text.trim().isNotEmpty) {
      body['telefono'] = _telefonoCtrl.text.trim();
    }
    body['edad'] = int.parse(_edadCtrl.text.trim());
    if (_esConductor && _ciudadCtrl.text.trim().isNotEmpty) {
      body['ciudad'] = _ciudadCtrl.text.trim();
    }

    if (_esConductor) {
      body['cedula'] = _cedulaCtrl.text.trim();
      body['placa'] = _placaCtrl.text.trim().toUpperCase();
      body['tipoVehiculo'] = _tipoVehiculo;
      body['capacidad'] = _capacidadCtrl.text.trim();
    }

    try {
      final auth = await ApiClient.instance.register(body);
      if (mounted) {
        // El registro ya autentica (guarda tokens y perfil): ir directo al
        // home del rol en lugar de pedir un segundo login.
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cuenta creada exitosamente')));
        final home = homeDestinoFor(rol: auth.rol, esModerador: auth.esModerador);
        if (home == HomeDestino.ninguno) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        } else {
          abrirInicioComoRaiz(context, homeScreenFor(home));
        }
      }
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
                    const Text(
                      'Solo te toma un minuto. Elige cómo usarás CargaExpress.',
                      style: TextStyle(fontSize: 15, color: AuthColores.gris, height: 1.35),
                    ),
                    const SizedBox(height: 22),
                    _TituloSeccion(paso: 1, titulo: 'Tipo de cuenta', total: _esConductor ? 3 : 2),
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
                              seleccionado: _rol == 'cliente',
                              onTap: () => setState(() => _rol = 'cliente'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _TarjetaRol(
                              key: const Key('rol_conductor'),
                              icono: Icons.local_shipping_outlined,
                              titulo: 'Conductor',
                              descripcion: 'Quiero transportar carga',
                              seleccionado: _esConductor,
                              onTap: () => setState(() => _rol = 'conductor'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),
                    _TituloSeccion(paso: 2, titulo: 'Datos personales', total: _esConductor ? 3 : 2),
                    const SizedBox(height: 12),
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
                            ),
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
                              ultimo: !_esConductor,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_esConductor) ...[
                      const SizedBox(height: 26),
                      const _TituloSeccion(paso: 3, titulo: 'Conductor y vehículo', total: 3),
                      const SizedBox(height: 12),
                      TarjetaAuth(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _campo(
                              controller: _cedulaCtrl,
                              label: 'Cédula',
                              icono: Icons.credit_card_outlined,
                              teclado: TextInputType.number,
                              maxLength: LimitesUsuario.cedula,
                              validator: _obligatorio,
                            ),
                            _campo(
                              controller: _placaCtrl,
                              label: 'Placa',
                              icono: Icons.pin_outlined,
                              capitalizacion: TextCapitalization.characters,
                              maxLength: LimitesUsuario.placa,
                              validator: _obligatorio,
                            ),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: DropdownButtonFormField<String>(
                                key: const Key('campo_tipo_vehiculo'),
                                initialValue: _tipoVehiculo,
                                isExpanded: true,
                                decoration: decoracionCampoAuth(
                                  label: 'Tipo de vehículo',
                                  icono: Icons.directions_car_outlined,
                                ),
                                items: _tiposVehiculo
                                    .map((t) => DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis)))
                                    .toList(),
                                onChanged: (v) => setState(() => _tipoVehiculo = v ?? 'Motocicleta'),
                              ),
                            ),
                            _campo(
                              controller: _capacidadCtrl,
                              label: 'Capacidad',
                              icono: Icons.scale_outlined,
                              ayuda: 'Ejemplo: 500 kg',
                              maxLength: LimitesUsuario.capacidad,
                              validator: _obligatorio,
                            ),
                            _campo(
                              controller: _ciudadCtrl,
                              label: 'Ciudad (zona de cobertura)',
                              icono: Icons.location_city_outlined,
                              maxLength: LimitesUsuario.ciudad,
                              capitalizacion: TextCapitalization.words,
                              ultimo: true,
                            ),
                          ],
                        ),
                      ),
                    ],
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
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: ultimo ? 0 : 14),
      child: TextFormField(
        controller: controller,
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
