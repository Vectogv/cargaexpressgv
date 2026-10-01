import 'package:google_sign_in/google_sign_in.dart';

/// ID de cliente web de Firebase (app-cargaexpress). No es secreto: Google lo
/// pone en el idToken y el servidor lo compara.
const _googleWebClientId = '848686850284-bi6477mo5t1ok3tgrha0vvnfmqcdcfma.apps.googleusercontent.com';

Future<void>? _inicio;

Future<void> _iniciar() =>
    _inicio ??= GoogleSignIn.instance.initialize(serverClientId: _googleWebClientId).catchError((Object e) {
      _inicio = null; // Permitir reintentar.
      throw e;
    });

/// Pide la cuenta de Google y devuelve su idToken, o null si el usuario cancela.
Future<String?> idTokenDeGoogle() async {
  await _iniciar();
  try {
    final cuenta = await GoogleSignIn.instance.authenticate();
    final idToken = cuenta.authentication.idToken;
    if (idToken == null) throw StateError('Google no devolvió el idToken');
    return idToken;
  } on GoogleSignInException catch (e) {
    if (e.code == GoogleSignInExceptionCode.canceled ||
        e.code == GoogleSignInExceptionCode.interrupted) {
      return null;
    }
    rethrow;
  }
}

/// Al cerrar sesión: olvidar la cuenta elegida para que el próximo usuario
/// del celular pueda escoger otra. Nunca falla.
Future<void> cerrarSesionGoogle() async {
  try {
    await _iniciar()
        .then((_) => GoogleSignIn.instance.signOut())
        .timeout(const Duration(seconds: 3));
  } catch (_) {}
}
