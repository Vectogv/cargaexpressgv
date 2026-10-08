import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../contracts/validacion_usuario.dart';
import '../../shared/ui_compartida.dart' show CajaIcono;
import '../auth_estilos.dart';
import '../google_login.dart' show BotonGoogleAuth;
import 'asistente_registro.dart';

/// Pasos que comparten el registro del cliente y el del conductor: datos
/// personales (con correo o con Google), edad y cédula. Cada pantalla
/// decide el orden en [pasos] y añade los suyos.
mixin PasosComunesRegistro<T extends StatefulWidget> on State<T> {
  /// Pasos de datos personales según el método: con correo se piden todos;
  /// con Google el nombre y el apellido vienen prellenados ("resumen").
  static const pasosCorreo = ['nombre', 'apellido', 'telefono', 'email', 'password', 'password2'];
  static const pasosGoogle = ['resumen', 'telefono'];

  /// Campos que van al borrador (nunca la contraseña).
  static const camposBorrador = ['nombre', 'apellido', 'telefono', 'email', 'edad', 'cedula'];

  final Map<String, TextEditingController> _controles = {};
  Map<String, dynamic>? google;
  String? idToken;
  String? error;
  bool obscure = true;

  /// Cédula opcional (cliente) u obligatoria (conductor).
  bool get cedulaOpcional => false;

  /// Detalle del paso del teléfono: a quién le sirve el número.
  String get detalleTelefono;

  /// Avanza al siguiente paso (lo llama Enter en los campos).
  void siguiente();

  TextEditingController ctrl(String paso) => _controles.putIfAbsent(paso, TextEditingController.new);
  String texto(String paso) => ctrl(paso).text.trim();

  @override
  void dispose() {
    for (final c in _controles.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Rellena con los datos que devolvió el servidor (404 CUENTA_NO_EXISTE).
  void usarGoogle(Map<String, dynamic> datos, String? token) {
    google = datos;
    idToken = token;
    ctrl('nombre').text = (datos['nombre'] ?? '').toString();
    ctrl('apellido').text = (datos['apellido'] ?? '').toString();
    ctrl('email').text = (datos['email'] ?? '').toString();
    error = null;
  }

  void limpiarError() {
    if (error != null) setState(() => error = null);
  }

  /// Error del paso o null si está bien. Los pasos que no son comunes dan null.
  String? validarComun(String paso) {
    final v = texto(paso);
    switch (paso) {
      case 'nombre':
      case 'apellido':
        return v.isEmpty ? 'Este campo es obligatorio' : null;
      case 'cedula':
        return validarCedula(v, opcional: cedulaOpcional);
      case 'resumen':
        return texto('nombre').isEmpty || texto('apellido').isEmpty ? 'Escribe tu nombre y apellido' : null;
      case 'telefono':
        return validarTelefono(v);
      case 'email':
        return v.isEmpty ? 'Ingresa tu correo electrónico' : validarEmail(v);
      case 'password':
        return ctrl('password').text.isEmpty ? 'Crea una contraseña' : validarPasswordRegistro(ctrl('password').text);
      case 'password2':
        return ctrl('password2').text != ctrl('password').text ? 'Las contraseñas no coinciden' : null;
      case 'edad':
        return validarEdad(v);
    }
    return null;
  }

  Widget campo(
    String paso, {
    required String label,
    required IconData icono,
    String? ayuda,
    TextInputType teclado = TextInputType.text,
    TextCapitalization capitalizacion = TextCapitalization.none,
    int? maxLength,
    bool soloDigitos = false,
    bool esPassword = false,
    bool habilitado = true,
    String? autofill,
    bool conError = true,
  }) {
    return TextField(
      key: Key('campo_$paso'),
      controller: ctrl(paso),
      autofocus: habilitado,
      enabled: habilitado,
      inputFormatters: [
        if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
        if (soloDigitos) FilteringTextInputFormatter.digitsOnly,
      ],
      keyboardType: teclado,
      obscureText: esPassword && obscure,
      autocorrect: !esPassword && teclado != TextInputType.emailAddress,
      enableSuggestions: !esPassword,
      textCapitalization: capitalizacion,
      textInputAction: TextInputAction.done,
      autofillHints: autofill == null ? null : [autofill],
      onChanged: (_) => limpiarError(),
      onSubmitted: (_) => siguiente(),
      decoration: decoracionCampoAuth(
        label: label,
        icono: icono,
        ayuda: ayuda,
        sufijo: esPassword
            ? IconButton(
                tooltip: obscure ? 'Mostrar contraseña' : 'Ocultar contraseña',
                icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                onPressed: () => setState(() => obscure = !obscure),
              )
            : null,
      ).copyWith(errorText: conError ? error : null),
    );
  }

  /// Vista de un paso común, o null si el paso es propio de la pantalla.
  Widget? contenidoComun(String paso) {
    switch (paso) {
      case 'nombre':
        return pantallaPaso('¿Cómo te llamas?', 'Escribe tu nombre como aparece en tu cédula.', [
          campo(paso, label: 'Nombre', icono: Icons.person_outline_rounded, teclado: TextInputType.name, capitalizacion: TextCapitalization.words, maxLength: LimitesUsuario.nombre, autofill: AutofillHints.givenName),
        ]);
      case 'apellido':
        return pantallaPaso('Tu apellido', 'Como aparece en tu cédula.', [
          campo(paso, label: 'Apellido', icono: Icons.badge_outlined, teclado: TextInputType.name, capitalizacion: TextCapitalization.words, maxLength: LimitesUsuario.apellido, autofill: AutofillHints.familyName),
        ]);
      case 'resumen':
        return pantallaPaso('Confirma tus datos', 'Los tomamos de tu cuenta de Google. Puedes corregir tu nombre.', [
          campo('nombre', label: 'Nombre', icono: Icons.person_outline_rounded, teclado: TextInputType.name, capitalizacion: TextCapitalization.words, maxLength: LimitesUsuario.nombre, conError: false),
          const SizedBox(height: 14),
          campo('apellido', label: 'Apellido', icono: Icons.badge_outlined, teclado: TextInputType.name, capitalizacion: TextCapitalization.words, maxLength: LimitesUsuario.apellido),
          const SizedBox(height: 14),
          campo('email', label: 'Correo electrónico', icono: Icons.mail_outline_rounded, habilitado: false, ayuda: 'Es el de tu cuenta de Google', conError: false),
        ]);
      case 'telefono':
        return pantallaPaso('Tu número de celular', detalleTelefono, [
          campo(paso, label: 'Teléfono', icono: Icons.phone_outlined, teclado: TextInputType.phone, maxLength: LimitesUsuario.telefono, autofill: AutofillHints.telephoneNumber),
        ]);
      case 'email':
        return pantallaPaso('Tu correo electrónico', 'Con él iniciarás sesión.', [
          campo(paso, label: 'Correo electrónico', icono: Icons.mail_outline_rounded, teclado: TextInputType.emailAddress, maxLength: LimitesUsuario.email, autofill: AutofillHints.email),
        ]);
      case 'password':
        return pantallaPaso('Crea una contraseña', 'Entre ${LimitesUsuario.passwordMin} y ${LimitesUsuario.passwordMax} caracteres.', [
          campo(paso, label: 'Contraseña', icono: Icons.lock_outline_rounded, esPassword: true, maxLength: LimitesUsuario.passwordMax, autofill: AutofillHints.newPassword),
        ]);
      case 'password2':
        return pantallaPaso('Confirma tu contraseña', 'Escríbela otra vez para asegurarnos.', [
          campo(paso, label: 'Confirmar contraseña', icono: Icons.lock_outline_rounded, esPassword: true, maxLength: LimitesUsuario.passwordMax),
        ]);
      case 'edad':
        return pantallaPaso('¿Cuántos años tienes?', 'Debes ser mayor de ${LimitesUsuario.edadMin} años.', [
          campo(paso, label: 'Edad', icono: Icons.cake_outlined, teclado: TextInputType.number, maxLength: 3, soloDigitos: true),
        ]);
      case 'cedula':
        return pantallaPaso('Tu número de cédula', cedulaOpcional ? 'Sin puntos ni espacios. Puedes dejarla vacía.' : 'Sin puntos ni espacios.', [
          campo(paso, label: cedulaOpcional ? 'Cédula (opcional)' : 'Cédula', icono: Icons.credit_card_outlined, teclado: TextInputType.number, maxLength: LimitesUsuario.cedula, soloDigitos: true),
        ]);
    }
    return null;
  }
}

/// Primer paso: Google o correo.
Widget vistaBienvenidaRegistro({
  required IconData icono,
  required String titulo,
  required String detalle,
  required Future<String?> Function()? obtenerIdToken,
  required void Function(Map<String, dynamic> google, String idToken) onGoogle,
  required VoidCallback onCorreo,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 12),
      Center(child: CajaIcono(icono: icono, tamano: 72)),
      const SizedBox(height: 22),
      tituloPaso(titulo, detalle),
      BotonGoogleAuth(obtenerIdToken: obtenerIdToken, onSinCuenta: onGoogle),
      const SizedBox(height: 12),
      BotonPrincipalAuth(
        key: const Key('btn_registro_correo'),
        texto: 'Registrarme con correo',
        textoCargando: '',
        cargando: false,
        onPressed: onCorreo,
      ),
      const SizedBox(height: 18),
      const Text(
        'Al continuar aceptas nuestras políticas y condiciones.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12.5, color: AuthColores.gris),
      ),
    ],
  );
}

/// Hay un borrador guardado: retomarlo o empezar de cero.
Widget vistaBorradorRegistro({required VoidCallback onContinuar, required VoidCallback onEmpezarDeNuevo}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 12),
      const Center(child: CajaIcono(icono: Icons.history_rounded, tamano: 72)),
      const SizedBox(height: 22),
      tituloPaso('Continúa tu registro', 'Dejaste un registro a medias. Puedes retomarlo donde lo dejaste.'),
      BotonPrincipalAuth(
        key: const Key('btn_continuar_registro'),
        texto: 'Continuar registro',
        textoCargando: '',
        cargando: false,
        onPressed: onContinuar,
      ),
      const SizedBox(height: 8),
      TextButton(key: const Key('btn_empezar_de_nuevo'), onPressed: onEmpezarDeNuevo, child: const Text('Empezar de nuevo')),
    ],
  );
}

/// Políticas en una tarjeta.
Widget vistaPoliticasRegistro(String titulo, String detalle, String texto) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      tituloPaso(titulo, detalle),
      TarjetaAuth(
        child: Text(texto.trim(), style: const TextStyle(fontSize: 14, color: AuthColores.texto, height: 1.45)),
      ),
    ],
  );
}
