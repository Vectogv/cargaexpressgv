import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../contracts/validacion_usuario.dart';
import '../../services/api_client.dart';
import '../../services/api/http_client.dart';
import '../home_by_role.dart';
import 'auth_estilos.dart';

/// ID de cliente web de Firebase (app-cargaexpress). No es secreto: Google lo
/// pone en el idToken y el servidor lo compara.
const _googleWebClientId = '848686850284-bi6477mo5t1ok3tgrha0vvnfmqcdcfma.apps.googleusercontent.com';

bool _googleIniciado = false;

/// Pide la cuenta de Google y devuelve su idToken, o null si el usuario cancela.
Future<String?> _idTokenDeGoogle() async {
  final google = GoogleSignIn.instance;
  if (!_googleIniciado) {
    await google.initialize(serverClientId: _googleWebClientId);
    _googleIniciado = true;
  }
  try {
    final cuenta = await google.authenticate();
    return cuenta.authentication.idToken;
  } on GoogleSignInException catch (e) {
    if (e.code == GoogleSignInExceptionCode.canceled ||
        e.code == GoogleSignInExceptionCode.interrupted) {
      return null;
    }
    rethrow;
  }
}

/// Botón "Continuar con Google" del login y del registro. Una cuenta nueva
/// queda como cliente; si faltan teléfono o edad se piden antes del inicio.
class BotonGoogleAuth extends StatefulWidget {
  /// Para pruebas: reemplaza el selector de cuentas de Google.
  final Future<String?> Function()? obtenerIdToken;
  const BotonGoogleAuth({super.key, this.obtenerIdToken});

  @override
  State<BotonGoogleAuth> createState() => _BotonGoogleAuthState();
}

class _BotonGoogleAuthState extends State<BotonGoogleAuth> {
  bool _cargando = false;
  String? _error;

  Future<void> _entrar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final idToken = await (widget.obtenerIdToken ?? _idTokenDeGoogle)();
      if (idToken == null) return; // Canceló el selector.
      final auth = await ApiClient.instance.loginGoogle(idToken);
      if (!mounted) return;
      final destino = homeDestinoFor(rol: auth.rol, esModerador: auth.esModerador);
      if (destino == HomeDestino.ninguno) {
        await ApiClient.instance.logout();
        if (mounted) setState(() => _error = 'Tu cuenta no tiene un rol habilitado en la app. Contacta a soporte.');
        return;
      }
      if (auth.perfilCompleto) {
        abrirInicioComoRaiz(context, homeScreenFor(destino));
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => CompletarPerfilScreen(destino: destino, nombre: auth.nombre)),
          (_) => false,
        );
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo entrar con Google. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 52,
          child: OutlinedButton.icon(
            key: const Key('btn_google'),
            onPressed: _cargando ? null : _entrar,
            style: OutlinedButton.styleFrom(
              foregroundColor: AuthColores.texto,
              backgroundColor: Colors.white,
              side: const BorderSide(color: AuthColores.borde),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: _cargando
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('G', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF4285F4))),
            label: Text(
              _cargando ? 'Entrando...' : 'Continuar con Google',
              style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          AvisoErrorAuth(mensaje: _error!),
        ],
      ],
    );
  }
}

/// Línea "o" entre el formulario y el botón de Google.
class SeparadorAuth extends StatelessWidget {
  final String texto;
  const SeparadorAuth({super.key, this.texto = 'o'});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          const Expanded(child: Divider(color: AuthColores.borde)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(texto, style: const TextStyle(color: AuthColores.gris, fontSize: 13.5)),
          ),
          const Expanded(child: Divider(color: AuthColores.borde)),
        ],
      ),
    );
  }
}

/// Después de entrar con Google por primera vez: el registro normal exige
/// teléfono y edad (mínimo 18), así que se piden aquí antes del inicio.
class CompletarPerfilScreen extends StatefulWidget {
  final HomeDestino destino;
  final String? nombre;
  const CompletarPerfilScreen({super.key, required this.destino, this.nombre});

  @override
  State<CompletarPerfilScreen> createState() => _CompletarPerfilScreenState();
}

class _CompletarPerfilScreenState extends State<CompletarPerfilScreen> {
  final _formKey = GlobalKey<FormState>();
  final _telCtrl = TextEditingController();
  final _edadCtrl = TextEditingController();
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _telCtrl.dispose();
    _edadCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await ApiClient.instance.updateProfile({
        'telefono': _telCtrl.text.trim(),
        'edad': int.parse(_edadCtrl.text.trim()),
      });
      if (mounted) abrirInicioComoRaiz(context, homeScreenFor(widget.destino));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudieron guardar tus datos. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AuthColores.fondo,
        appBar: AppBar(
          backgroundColor: AuthColores.fondo,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: const MarcaCargaExpress(tamano: 17),
          centerTitle: true,
        ),
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Hola${widget.nombre == null ? '' : ' ${widget.nombre}'}, ya casi',
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AuthColores.texto, letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Necesitamos tu teléfono para que el conductor pueda llamarte, y tu edad (debes ser mayor de 18).',
                    style: TextStyle(fontSize: 15, color: AuthColores.gris, height: 1.35),
                  ),
                  const SizedBox(height: 22),
                  TarjetaAuth(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          key: const Key('campo_telefono_google'),
                          controller: _telCtrl,
                          enabled: !_guardando,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          validator: (v) => validarTelefono(v ?? ''),
                          decoration: decoracionCampoAuth(label: 'Teléfono', icono: Icons.phone_outlined),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          key: const Key('campo_edad_google'),
                          controller: _edadCtrl,
                          enabled: !_guardando,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          validator: (v) => validarEdad(v ?? ''),
                          onFieldSubmitted: (_) => _guardando ? null : _guardar(),
                          decoration: decoracionCampoAuth(label: 'Edad', icono: Icons.cake_outlined),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          AvisoErrorAuth(mensaje: _error!),
                        ],
                        const SizedBox(height: 16),
                        BotonPrincipalAuth(
                          key: const Key('btn_completar_perfil'),
                          texto: 'Continuar',
                          textoCargando: 'Guardando...',
                          cargando: _guardando,
                          onPressed: _guardar,
                        ),
                      ],
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
