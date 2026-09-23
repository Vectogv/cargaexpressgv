import 'package:flutter/material.dart';
import '../../contracts/validacion_usuario.dart';
import '../../services/api_client.dart';
import '../../services/api/http_client.dart';
import '../home_by_role.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      _showSnack('Completa todos los campos');
      return;
    }
    final errorEmail = validarEmail(_emailCtrl.text);
    if (errorEmail != null) {
      _showSnack(errorEmail);
      return;
    }
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
          _showSnack('Tu cuenta no tiene un rol habilitado en la app. Contacta a soporte.');
          return;
        }
        _showSnack('Bienvenido ${auth.nombre}');
        abrirInicioComoRaiz(context, homeScreenFor(destino));
      }
    } catch (e) {
      if (mounted) {
        if (e is ApiException && e.statusCode == 403) {
          _showSnack(
            e.message,
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 5),
          );
        } else if (e is ApiException &&
            e.statusCode == 400 &&
            e.message == 'Invalid user credentials') {
          _showSnack('Correo o contraseña incorrectos');
        } else {
          final msg = e.toString().replaceFirst('Exception: ', '');
          _showSnack(msg);
        }
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String msg,
      {Color? backgroundColor, Duration? duration}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: backgroundColor,
      duration: duration ?? const Duration(milliseconds: 4000),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'Carga',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w400,
                    color: Colors.black87),
              ),
              TextSpan(
                text: 'Express',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87),
              ),
            ],
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 32),
            const Text(
              'Iniciar Sesión',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 24),
            _buildField(
              controller: _emailCtrl,
              label: 'Correo electrónico',
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 14),
            _buildField(
              controller: _passCtrl,
              label: 'Contraseña',
              obscure: _obscure,
              suffix: IconButton(
                icon: Icon(
                    _obscure ? Icons.visibility_off : Icons.visibility,
                    color: Colors.black45,
                    size: 20),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                  elevation: 0,
                ),
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Iniciar Sesión',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w500)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.black45, fontSize: 14),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
