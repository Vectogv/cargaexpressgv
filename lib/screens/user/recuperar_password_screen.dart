import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../contracts/validacion_usuario.dart' show validarEmail;
import '../../services/api/auth_service.dart';
import '../../services/api/http_client.dart' show ApiException;
import '../shared/cambiar_password.dart' show mostrarAyudaPasswordOlvidada;
import 'auth_estilos.dart';

/// "¿Olvidaste tu contraseña?": 1) el correo recibe un código de 6 dígitos
/// (POST /api/auth/forgot-password), 2) código + contraseña nueva
/// (POST /api/auth/reset-password). Devuelve `true` al cambiarla.
class RecuperarPasswordScreen extends StatefulWidget {
  final String email;
  const RecuperarPasswordScreen({super.key, this.email = ''});

  @override
  State<RecuperarPasswordScreen> createState() => _RecuperarPasswordScreenState();
}

class _RecuperarPasswordScreenState extends State<RecuperarPasswordScreen> {
  // Igual que resetPasswordValidator del servidor (8 a 72).
  static const int _minimoPassword = 8;
  static const int _maximoPassword = 72;

  late final _email = TextEditingController(text: widget.email);
  final _codigo = TextEditingController();
  final _nueva = TextEditingController();
  final _confirmar = TextEditingController();
  bool _codigoEnviado = false;
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _codigo.dispose();
    _nueva.dispose();
    _confirmar.dispose();
    super.dispose();
  }

  Future<void> _ejecutar(Future<void> Function() accion) async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await accion();
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _enviarCodigo() async {
    final email = _email.text.trim();
    final errorEmail = validarEmail(email);
    if (errorEmail != null) {
      setState(() => _error = errorEmail);
      return;
    }
    await _ejecutar(() async {
      await AuthService.forgotPassword(email);
      if (!mounted) return;
      setState(() => _codigoEnviado = true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Si el correo está registrado, te enviamos un código')));
    });
  }

  Future<void> _cambiar() async {
    if (_codigo.text.length != 6) {
      setState(() => _error = 'El código tiene 6 dígitos');
      return;
    }
    if (_nueva.text.length < _minimoPassword) {
      setState(() => _error = 'La nueva contraseña debe tener al menos $_minimoPassword caracteres');
      return;
    }
    if (_nueva.text.length > _maximoPassword) {
      setState(() => _error = 'La nueva contraseña puede tener máximo $_maximoPassword caracteres');
      return;
    }
    if (_nueva.text != _confirmar.text) {
      setState(() => _error = 'Las contraseñas no coinciden');
      return;
    }
    await _ejecutar(() async {
      await AuthService.resetPassword(_email.text.trim(), _codigo.text, _nueva.text);
      if (mounted) Navigator.pop(context, true);
    });
  }

  Widget _password(Key key, TextEditingController c, String label) => TextField(
        key: key,
        controller: c,
        obscureText: true,
        enabled: !_cargando,
        decoration: decoracionCampoAuth(label: label, icono: Icons.lock_outline_rounded),
      );

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
                  const Text('Recuperar contraseña', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AuthColores.texto)),
                  const SizedBox(height: 6),
                  Text(
                    _codigoEnviado
                        ? 'Escribe el código que enviamos a ${_email.text.trim()}. Vence en 10 minutos; revisa también Spam.'
                        : 'Te enviaremos un código de 6 dígitos a tu correo.',
                    style: const TextStyle(fontSize: 14, color: AuthColores.gris, height: 1.4),
                  ),
                  const SizedBox(height: 18),
                  TarjetaAuth(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          key: const Key('campo_recuperar_email'),
                          controller: _email,
                          enabled: !_cargando && !_codigoEnviado,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          decoration: decoracionCampoAuth(label: 'Correo electrónico', icono: Icons.mail_outline_rounded),
                        ),
                        if (_codigoEnviado) ...[
                          const SizedBox(height: 14),
                          TextField(
                            key: const Key('campo_recuperar_codigo'),
                            controller: _codigo,
                            enabled: !_cargando,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: decoracionCampoAuth(label: 'Código de 6 dígitos', icono: Icons.pin_outlined),
                          ),
                          const SizedBox(height: 14),
                          _password(const Key('campo_recuperar_nueva'), _nueva, 'Nueva contraseña'),
                          const SizedBox(height: 14),
                          _password(const Key('campo_recuperar_confirmar'), _confirmar, 'Confirmar contraseña'),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          AvisoErrorAuth(mensaje: _error!),
                        ],
                        const SizedBox(height: 16),
                        BotonPrincipalAuth(
                          key: const Key('btn_recuperar'),
                          texto: _codigoEnviado ? 'Cambiar contraseña' : 'Enviar código',
                          textoCargando: _codigoEnviado ? 'Cambiando…' : 'Enviando…',
                          cargando: _cargando,
                          onPressed: _codigoEnviado ? _cambiar : _enviarCodigo,
                        ),
                        if (_codigoEnviado)
                          TextButton(
                            key: const Key('btn_reenviar_codigo'),
                            onPressed: _cargando ? null : _enviarCodigo,
                            child: const Text('Reenviar código'),
                          ),
                        if (_codigoEnviado)
                          TextButton(
                            key: const Key('btn_cambiar_correo'),
                            onPressed: _cargando
                                ? null
                                : () => setState(() {
                                      _codigoEnviado = false;
                                      _codigo.clear();
                                      _error = null;
                                    }),
                            child: const Text('Cambiar correo'),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => mostrarAyudaPasswordOlvidada(context),
                    style: TextButton.styleFrom(foregroundColor: AuthColores.gris),
                    child: const Text('¿No te llega el código? Escribe a soporte'),
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
