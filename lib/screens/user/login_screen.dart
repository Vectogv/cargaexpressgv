import 'package:flutter/material.dart';
import '../../contracts/validacion_usuario.dart';
import '../../services/api_client.dart';
import '../../services/api/http_client.dart';
import '../home_by_role.dart';
import 'auth_estilos.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  bool _intentado = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  String? _validarEmail(String? v) {
    if ((v ?? '').trim().isEmpty) return 'Ingresa tu correo electrónico';
    return validarEmail(v!);
  }

  String? _validarPassword(String? v) {
    if ((v ?? '').isEmpty) return 'Ingresa tu contraseña';
    return null;
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _intentado = true;
      _error = null;
    });
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _loading = true);
    try {
      final auth = await ApiClient.instance.login(
        _emailCtrl.text.trim(),
        _passCtrl.text,
      );
      if (mounted) {
        final destino = homeDestinoFor(
          rol: auth.rol,
          esModerador: auth.esModerador,
        );
        if (destino == HomeDestino.ninguno) {
          // Rol sin pantalla en la app: no dejar una sesión "colgada".
          await ApiClient.instance.logout();
          if (!mounted) return;
          setState(() => _error = 'Tu cuenta no tiene un rol habilitado en la app. Contacta a soporte.');
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Bienvenido ${auth.nombre}')));
        abrirInicioComoRaiz(context, homeScreenFor(destino));
      }
    } catch (e) {
      if (mounted) setState(() => _error = _mensajeError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static String _mensajeError(Object e) {
    if (e is ApiException && e.statusCode == 400 && e.message == 'Invalid user credentials') {
      return 'Correo o contraseña incorrectos';
    }
    if (e is ApiException) return e.message;
    return e.toString().replaceFirst('Exception: ', '');
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
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Bienvenido de nuevo',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AuthColores.texto, letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Ingresa para gestionar tus envíos y viajes.',
                    style: TextStyle(fontSize: 15, color: AuthColores.gris, height: 1.35),
                  ),
                  const SizedBox(height: 22),
                  TarjetaAuth(
                    child: Form(
                      key: _formKey,
                      autovalidateMode: _intentado ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
                      child: AutofillGroup(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              key: const Key('campo_email'),
                              controller: _emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.email],
                              autocorrect: false,
                              validator: _validarEmail,
                              decoration: decoracionCampoAuth(label: 'Correo electrónico', icono: Icons.mail_outline_rounded),
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              key: const Key('campo_password'),
                              controller: _passCtrl,
                              obscureText: _obscure,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.password],
                              autocorrect: false,
                              enableSuggestions: false,
                              validator: _validarPassword,
                              onFieldSubmitted: (_) => _loading ? null : _login(),
                              decoration: decoracionCampoAuth(
                                label: 'Contraseña',
                                icono: Icons.lock_outline_rounded,
                                sufijo: IconButton(
                                  tooltip: _obscure ? 'Mostrar contraseña' : 'Ocultar contraseña',
                                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                                  onPressed: () => setState(() => _obscure = !_obscure),
                                ),
                              ),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 16),
                              AvisoErrorAuth(mensaje: _error!),
                            ],
                            const SizedBox(height: 20),
                            BotonPrincipalAuth(
                              key: const Key('btn_login'),
                              texto: 'Iniciar sesión',
                              textoCargando: 'Ingresando...',
                              cargando: _loading,
                              onPressed: _login,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  EnlaceAuth(
                    botonKey: const Key('link_registro'),
                    pregunta: '¿No tienes cuenta?',
                    accion: 'Regístrate',
                    onTap: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                    ),
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
