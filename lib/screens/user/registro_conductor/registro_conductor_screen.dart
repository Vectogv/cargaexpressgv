import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../contracts/validacion_usuario.dart';
import '../../../services/api/coverage_service.dart';
import '../../../services/api/http_client.dart' show ApiException;
import '../../../services/api_client.dart';
import '../../../services/google_auth.dart';
import '../../../widgets/error_carga.dart' show mensajeDeError;
import '../../home_by_role.dart';
import '../../shared/ui_compartida.dart' show BotonSecundario, CajaIcono, ColoresApp, OpcionRadio;
import '../auth_estilos.dart';
import '../google_login.dart' show BotonGoogleAuth;
import 'politicas_conductor.dart';

/// Tipos de vehículo que acepta el registro (mismos valores que el backend).
const List<String> tiposVehiculoRegistro = ['Motocicleta', 'Sedan', 'Camioneta', 'Camion', 'Furgon'];

/// Clave de SharedPreferences del borrador del registro (sin contraseña ni idToken).
const String claveBorradorRegistroConductor = 'registro_conductor_borrador';

/// Asistente de registro del conductor: una pregunta por pantalla. Con
/// Google o con correo termina en la misma alta (`POST /api/auth/register`,
/// con `idToken` o `password`) y luego sube la foto del conductor y la del
/// vehículo con la sesión recién creada.
class RegistroConductorScreen extends StatefulWidget {
  /// Datos que devolvió el servidor con 404 CUENTA_NO_EXISTE (`google`) y el
  /// idToken con el que se pidieron, cuando se llega desde el login.
  final Map<String, dynamic>? google;
  final String? idToken;

  /// Para pruebas: reemplaza el selector de cuentas de Google.
  final Future<String?> Function()? obtenerIdToken;

  /// Para pruebas: reemplaza la cámara/galería.
  final Future<Uint8List?> Function(ImageSource origen)? elegirFoto;

  const RegistroConductorScreen({super.key, this.google, this.idToken, this.obtenerIdToken, this.elegirFoto});

  @override
  State<RegistroConductorScreen> createState() => _RegistroConductorScreenState();
}

class _Foto {
  final Uint8List bytes;
  final String? ruta;
  const _Foto(this.bytes, this.ruta);
}

class _RegistroConductorScreenState extends State<RegistroConductorScreen> {
  static const _pasosTexto = ['nombre', 'apellido', 'telefono', 'email', 'password', 'password2', 'edad', 'cedula', 'modelo', 'placa', 'capacidad'];
  static const _conBorrador = ['nombre', 'apellido', 'telefono', 'email', 'edad', 'cedula', 'modelo', 'placa', 'capacidad'];

  final Map<String, TextEditingController> _c = {for (final p in _pasosTexto) p: TextEditingController()};
  Map<String, dynamic>? _google;
  String? _idToken;
  int _i = 0;
  String? _error;
  bool _obscure = true;
  String _tipoVehiculo = tiposVehiculoRegistro.first;
  String? _zona;
  List<Map<String, dynamic>>? _zonas;
  _Foto? _fotoConductor;
  _Foto? _fotoVehiculo;
  bool _enviando = false;
  bool _registrado = false;
  bool _fotoConductorSubida = false;
  bool _fotoVehiculoSubida = false;
  /// null: aún no se leyó SharedPreferences; vacío: sin borrador.
  Map<String, dynamic>? _borrador;
  bool _borradorLeido = false;

  List<String> get _pasos => [
        'bienvenida',
        'politicas',
        ...(_google == null ? ['nombre', 'apellido', 'telefono', 'email', 'password', 'password2'] : ['resumen', 'telefono']),
        'edad', 'cedula', 'foto_conductor', 'modelo', 'tipo', 'placa', 'foto_vehiculo', 'zona', 'enviando', 'listo',
      ];

  String get _paso => _pasos[_i];

  @override
  void initState() {
    super.initState();
    if (widget.google != null) _usarGoogle(widget.google!, widget.idToken, avanzar: false);
    _leerBorrador();
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Google ──

  void _usarGoogle(Map<String, dynamic> google, String? idToken, {bool avanzar = true}) {
    setState(() {
      _google = google;
      _idToken = idToken;
      _c['nombre']!.text = (google['nombre'] ?? '').toString();
      _c['apellido']!.text = (google['apellido'] ?? '').toString();
      _c['email']!.text = (google['email'] ?? '').toString();
      _error = null;
      if (avanzar) _i = 1;
    });
  }

  Future<String?> _tokenGoogle() => (widget.obtenerIdToken ?? idTokenDeGoogle)();

  // ── Borrador ──

  Future<void> _leerBorrador() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(claveBorradorRegistroConductor);
    Map<String, dynamic>? b;
    if (raw != null) {
      try {
        b = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      } catch (_) {
        await prefs.remove(claveBorradorRegistroConductor);
      }
    }
    if (!mounted) return;
    setState(() {
      _borradorLeido = true;
      // Si se llega desde el login con Google, ese dato manda sobre el borrador.
      _borrador = widget.google == null ? b : null;
    });
  }

  Future<void> _guardarBorrador() async {
    if (_i < 2 || _registrado) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      claveBorradorRegistroConductor,
      jsonEncode({
        'metodo': _google == null ? 'correo' : 'google',
        'paso': _paso,
        'campos': {for (final p in _conBorrador) p: _c[p]!.text},
        'tipo': _tipoVehiculo,
        'zona': _zona,
        'fotoConductor': _fotoConductor?.ruta,
        'fotoVehiculo': _fotoVehiculo?.ruta,
        'google': _google,
      }),
    );
  }

  Future<void> _borrarBorrador() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(claveBorradorRegistroConductor);
  }

  Future<_Foto?> _fotoDesdeRuta(dynamic ruta) async {
    if (ruta is! String || ruta.isEmpty) return null;
    try {
      return _Foto(await File(ruta).readAsBytes(), ruta);
    } catch (_) {
      return null;
    }
  }

  Future<void> _continuarBorrador() async {
    final b = _borrador!;
    final campos = (b['campos'] as Map?) ?? {};
    for (final p in _conBorrador) {
      _c[p]!.text = (campos[p] ?? '').toString();
    }
    final google = b['google'];
    _google = b['metodo'] == 'google' && google is Map ? Map<String, dynamic>.from(google) : null;
    _tipoVehiculo = tiposVehiculoRegistro.contains(b['tipo']) ? b['tipo'] as String : _tipoVehiculo;
    _zona = b['zona'] as String?;
    _fotoConductor = await _fotoDesdeRuta(b['fotoConductor']);
    _fotoVehiculo = await _fotoDesdeRuta(b['fotoVehiculo']);
    if (!mounted) return;
    // Primer paso incompleto (la contraseña nunca se guarda, así que se vuelve a pedir).
    final pasos = _pasos;
    var destino = pasos.indexOf('zona');
    for (var k = 2; k < pasos.indexOf('enviando'); k++) {
      if (_validar(pasos[k]) != null) {
        destino = k;
        break;
      }
    }
    setState(() {
      _borrador = null;
      _error = null;
      _i = destino;
    });
    if (_paso == 'zona') _cargarZonas();
  }

  Future<void> _empezarDeNuevo() async {
    await _borrarBorrador();
    if (mounted) setState(() => _borrador = null);
  }

  // ── Validación y navegación ──

  String? _validar(String paso) {
    final v = _c[paso]?.text.trim() ?? '';
    switch (paso) {
      case 'nombre':
      case 'apellido':
      case 'cedula':
      case 'modelo':
      case 'placa':
        return v.isEmpty ? 'Este campo es obligatorio' : null;
      case 'resumen':
        return _c['nombre']!.text.trim().isEmpty || _c['apellido']!.text.trim().isEmpty ? 'Escribe tu nombre y apellido' : null;
      case 'telefono':
        return validarTelefono(v);
      case 'email':
        return v.isEmpty ? 'Ingresa tu correo electrónico' : validarEmail(v);
      case 'password':
        return _c['password']!.text.isEmpty ? 'Crea una contraseña' : validarPasswordRegistro(_c['password']!.text);
      case 'password2':
        return _c['password2']!.text != _c['password']!.text ? 'Las contraseñas no coinciden' : null;
      case 'edad':
        return validarEdad(v);
      case 'tipo':
        return _c['capacidad']!.text.trim().isEmpty ? 'Indica la capacidad de carga' : null;
      case 'foto_conductor':
        return _fotoConductor == null ? 'Sube una foto tuya para continuar' : null;
      case 'foto_vehiculo':
        return _fotoVehiculo == null ? 'Sube una foto del vehículo para continuar' : null;
      case 'zona':
        return _zona == null ? 'Elige la zona donde vas a trabajar' : null;
    }
    return null;
  }

  void _siguiente() {
    final e = _validar(_paso);
    if (e != null) {
      setState(() => _error = e);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      _i++;
    });
    if (_paso == 'enviando') {
      _enviar();
    } else {
      _guardarBorrador();
      if (_paso == 'zona') _cargarZonas();
    }
  }

  void _atras() {
    if (_enviando || _paso == 'listo') return;
    if (_i == 0) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _error = null;
      _i--;
      if (_paso == 'enviando') _i--;
    });
  }

  void _limpiarError() {
    if (_error != null) setState(() => _error = null);
  }

  Future<void> _cargarZonas() async {
    if (_zonas != null) return;
    List<Map<String, dynamic>> zonas = const [];
    try {
      zonas = await CoverageService.getCoverage();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _zonas = zonas.where((z) => z['clave'] != null && z['nombre'] != null).toList();
      if (_zonas!.isEmpty) _zonas = [{'clave': 'popayan', 'nombre': 'Popayán'}];
      if (!_zonas!.any((z) => z['clave'] == _zona)) _zona = null;
    });
  }

  // ── Fotos ──

  Future<void> _elegirFoto(ImageSource origen) async {
    _Foto? foto;
    try {
      if (widget.elegirFoto != null) {
        final bytes = await widget.elegirFoto!(origen);
        if (bytes != null) foto = _Foto(bytes, null);
      } else {
        final picked = await ImagePicker().pickImage(source: origen, maxWidth: 1600, maxHeight: 1600, imageQuality: 75);
        if (picked != null) foto = _Foto(await picked.readAsBytes(), picked.path);
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo abrir la ${origen == ImageSource.camera ? 'cámara' : 'galería'}.');
      return;
    }
    if (foto == null || !mounted) return;
    setState(() {
      _error = null;
      if (_paso == 'foto_conductor') {
        _fotoConductor = foto;
        _fotoConductorSubida = false;
      } else {
        _fotoVehiculo = foto;
        _fotoVehiculoSubida = false;
      }
    });
    _guardarBorrador();
  }

  // ── Alta ──

  Map<String, dynamic> _cuerpo() => {
        'nombre': _c['nombre']!.text.trim(),
        'apellido': _c['apellido']!.text.trim(),
        'email': _c['email']!.text.trim(),
        if (_google == null) 'password': _c['password']!.text else 'idToken': _idToken,
        'rol': 'conductor',
        'edad': int.parse(_c['edad']!.text.trim()),
        'telefono': _c['telefono']!.text.trim(),
        'cedula': _c['cedula']!.text.trim(),
        'placa': _c['placa']!.text.trim().toUpperCase(),
        'tipoVehiculo': _tipoVehiculo,
        'capacidad': _c['capacidad']!.text.trim(),
        'ciudad': _zona,
        'modeloVehiculo': _c['modelo']!.text.trim(),
        'aceptaTerminos': true,
      };

  Future<void> _enviar() async {
    setState(() {
      _error = null;
      _enviando = true;
    });
    try {
      if (!_registrado) {
        if (_google != null && _idToken == null) {
          // Borrador con Google: el idToken nunca se guarda, se pide otra vez.
          _idToken = await _tokenGoogle();
          if (_idToken == null) throw Exception('Necesitamos confirmar tu cuenta de Google para terminar.');
        }
        try {
          await ApiClient.instance.register(_cuerpo());
        } on ApiException catch (e) {
          if (e.statusCode != 401 || _google == null) rethrow;
          // El idToken venció mientras llenaba el formulario: uno nuevo y un solo reintento.
          _idToken = await _tokenGoogle();
          if (_idToken == null) rethrow;
          await ApiClient.instance.register(_cuerpo());
        }
        if (!mounted) {
          await ApiClient.instance.logout();
          return;
        }
        _registrado = true;
        await _borrarBorrador();
      }
      final ts = DateTime.now().millisecondsSinceEpoch;
      if (!_fotoConductorSubida) {
        await ApiClient.instance.uploadDocumentDriverPhoto(_fotoConductor!.bytes, 'foto_conductor_$ts.jpg');
        _fotoConductorSubida = true;
      }
      if (!_fotoVehiculoSubida) {
        await ApiClient.instance.uploadDocumentVehiculo(_fotoVehiculo!.bytes, 'foto_vehiculo_$ts.jpg');
        _fotoVehiculoSubida = true;
      }
      if (mounted) setState(() => _i = _pasos.indexOf('listo'));
    } on ApiException catch (e) {
      if (!mounted) return;
      final paso = _registrado
          ? null
          : switch (e.code) {
              'EMAIL_DUPLICADO' => _google == null ? 'email' : 'resumen',
              'PLACA_DUPLICADA' => 'placa',
              'CEDULA_DUPLICADA' => 'cedula',
              _ => null,
            };
      setState(() {
        _error = e.message;
        if (paso != null) _i = _pasos.indexOf(paso);
      });
    } catch (e) {
      if (mounted) setState(() => _error = mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  // ── UI ──

  @override
  Widget build(BuildContext context) {
    final paso = _paso;
    final pregunta = _i >= 2 && paso != 'enviando' && paso != 'listo';
    final sinVolver = _enviando || paso == 'listo' || _borrador != null;
    return PopScope(
      canPop: _i == 0 && !sinVolver,
      onPopInvokedWithResult: (hecho, _) {
        if (!hecho && !sinVolver) _atras();
      },
      child: Scaffold(
        backgroundColor: AuthColores.fondo,
        appBar: AppBar(
          backgroundColor: AuthColores.fondo,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          leading: sinVolver ? null : BackButton(key: const Key('btn_atras'), color: AuthColores.texto, onPressed: _atras),
          title: const MarcaCargaExpress(tamano: 17),
          centerTitle: true,
          bottom: pregunta
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(4),
                  child: LinearProgressIndicator(
                    value: (_i - 1) / (_pasos.indexOf('zona') - 1),
                    minHeight: 4,
                    backgroundColor: AuthColores.borde,
                    color: AuthColores.primario,
                  ),
                )
              : null,
        ),
        body: !_borradorLeido
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                top: false,
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 520),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              switchInCurve: Curves.easeOut,
                              switchOutCurve: Curves.easeIn,
                              transitionBuilder: (child, anim) => FadeTransition(
                                opacity: anim,
                                child: SlideTransition(
                                  position: Tween(begin: const Offset(0.04, 0), end: Offset.zero).animate(anim),
                                  child: child,
                                ),
                              ),
                              layoutBuilder: (actual, previos) => Stack(
                                alignment: Alignment.topCenter,
                                children: [...previos, if (actual != null) actual],
                              ),
                              child: KeyedSubtree(
                                key: ValueKey(_borrador != null ? 'borrador' : paso),
                                child: _borrador != null ? _vistaBorrador() : _contenido(paso),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (pregunta || paso == 'politicas')
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 520),
                            child: BotonPrincipalAuth(
                              key: const Key('btn_continuar'),
                              texto: paso == 'politicas'
                                  ? 'Aceptar y continuar'
                                  : paso == 'zona'
                                      ? 'Crear mi cuenta'
                                      : 'Continuar',
                              textoCargando: '',
                              cargando: false,
                              onPressed: _siguiente,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _titulo(String titulo, String detalle) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(titulo, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AuthColores.texto, letterSpacing: -0.5, height: 1.15)),
          const SizedBox(height: 6),
          Text(detalle, style: const TextStyle(fontSize: 15, color: AuthColores.gris, height: 1.35)),
          const SizedBox(height: 22),
        ],
      );

  Widget _pantalla(String titulo, String detalle, List<Widget> hijos) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _titulo(titulo, detalle),
          TarjetaAuth(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: hijos)),
        ],
      );

  Widget _campo(
    String paso, {
    required String label,
    required IconData icono,
    String? ayuda,
    TextInputType teclado = TextInputType.text,
    TextCapitalization capitalizacion = TextCapitalization.none,
    int? maxLength,
    bool soloDigitos = false,
    bool obscure = false,
    bool habilitado = true,
    String? autofill,
    bool conError = true,
  }) {
    return TextField(
      key: Key('campo_$paso'),
      controller: _c[paso],
      autofocus: habilitado,
      enabled: habilitado,
      inputFormatters: [
        if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
        if (soloDigitos) FilteringTextInputFormatter.digitsOnly,
      ],
      keyboardType: teclado,
      obscureText: obscure && _obscure,
      autocorrect: !obscure && teclado != TextInputType.emailAddress,
      enableSuggestions: !obscure,
      textCapitalization: capitalizacion,
      textInputAction: TextInputAction.done,
      autofillHints: autofill == null ? null : [autofill],
      onChanged: (_) => _limpiarError(),
      onSubmitted: (_) => _siguiente(),
      decoration: decoracionCampoAuth(
        label: label,
        icono: icono,
        ayuda: ayuda,
        sufijo: obscure
            ? IconButton(
                tooltip: _obscure ? 'Mostrar contraseña' : 'Ocultar contraseña',
                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                onPressed: () => setState(() => _obscure = !_obscure),
              )
            : null,
      ).copyWith(errorText: conError ? _error : null),
    );
  }

  Widget _contenido(String paso) {
    switch (paso) {
      case 'bienvenida':
        return _vistaBienvenida();
      case 'politicas':
        return _vistaPoliticas();
      case 'nombre':
        return _pantalla('¿Cómo te llamas?', 'Escribe tu nombre como aparece en tu cédula.', [
          _campo(paso, label: 'Nombre', icono: Icons.person_outline_rounded, teclado: TextInputType.name, capitalizacion: TextCapitalization.words, maxLength: LimitesUsuario.nombre, autofill: AutofillHints.givenName),
        ]);
      case 'apellido':
        return _pantalla('Tu apellido', 'Como aparece en tu cédula.', [
          _campo(paso, label: 'Apellido', icono: Icons.badge_outlined, teclado: TextInputType.name, capitalizacion: TextCapitalization.words, maxLength: LimitesUsuario.apellido, autofill: AutofillHints.familyName),
        ]);
      case 'resumen':
        return _pantalla('Confirma tus datos', 'Los tomamos de tu cuenta de Google. Puedes corregir tu nombre.', [
          _campo('nombre', label: 'Nombre', icono: Icons.person_outline_rounded, teclado: TextInputType.name, capitalizacion: TextCapitalization.words, maxLength: LimitesUsuario.nombre, conError: false),
          const SizedBox(height: 14),
          _campo('apellido', label: 'Apellido', icono: Icons.badge_outlined, teclado: TextInputType.name, capitalizacion: TextCapitalization.words, maxLength: LimitesUsuario.apellido),
          const SizedBox(height: 14),
          _campo('email', label: 'Correo electrónico', icono: Icons.mail_outline_rounded, habilitado: false, ayuda: 'Es el de tu cuenta de Google', conError: false),
        ]);
      case 'telefono':
        return _pantalla('Tu número de celular', 'Los clientes te llamarán a este número.', [
          _campo(paso, label: 'Teléfono', icono: Icons.phone_outlined, teclado: TextInputType.phone, maxLength: LimitesUsuario.telefono, autofill: AutofillHints.telephoneNumber),
        ]);
      case 'email':
        return _pantalla('Tu correo electrónico', 'Con él iniciarás sesión.', [
          _campo(paso, label: 'Correo electrónico', icono: Icons.mail_outline_rounded, teclado: TextInputType.emailAddress, maxLength: LimitesUsuario.email, autofill: AutofillHints.email),
        ]);
      case 'password':
        return _pantalla('Crea una contraseña', 'Entre ${LimitesUsuario.passwordMin} y ${LimitesUsuario.passwordMax} caracteres.', [
          _campo(paso, label: 'Contraseña', icono: Icons.lock_outline_rounded, obscure: true, maxLength: LimitesUsuario.passwordMax, autofill: AutofillHints.newPassword),
        ]);
      case 'password2':
        return _pantalla('Confirma tu contraseña', 'Escríbela otra vez para asegurarnos.', [
          _campo(paso, label: 'Confirmar contraseña', icono: Icons.lock_outline_rounded, obscure: true, maxLength: LimitesUsuario.passwordMax),
        ]);
      case 'edad':
        return _pantalla('¿Cuántos años tienes?', 'Debes ser mayor de ${LimitesUsuario.edadMin} años.', [
          _campo(paso, label: 'Edad', icono: Icons.cake_outlined, teclado: TextInputType.number, maxLength: 3, soloDigitos: true),
        ]);
      case 'cedula':
        return _pantalla('Tu número de cédula', 'Sin puntos ni espacios.', [
          _campo(paso, label: 'Cédula', icono: Icons.credit_card_outlined, teclado: TextInputType.number, maxLength: LimitesUsuario.cedula, soloDigitos: true),
        ]);
      case 'foto_conductor':
        return _vistaFoto('Ahora necesitamos conocerte', 'Sube una foto tuya para validar tu identidad.', _fotoConductor, Icons.person_outline_rounded);
      case 'modelo':
        return _pantalla('Cuéntanos sobre tu vehículo', '¿Qué marca y modelo es? Ejemplo: Chevrolet NHR 2018.', [
          _campo(paso, label: 'Marca y modelo', icono: Icons.directions_car_outlined, capitalizacion: TextCapitalization.words, maxLength: 100),
        ]);
      case 'tipo':
        return _vistaTipo();
      case 'placa':
        return _pantalla('Placa del vehículo', 'Como aparece en la tarjeta de propiedad.', [
          _campo(paso, label: 'Placa', icono: Icons.pin_outlined, capitalizacion: TextCapitalization.characters, maxLength: LimitesUsuario.placa, ayuda: 'Ejemplo: ABC123'),
        ]);
      case 'foto_vehiculo':
        return _vistaFoto('Foto del vehículo', 'Que se vea completo y con la placa legible.', _fotoVehiculo, Icons.local_shipping_outlined);
      case 'zona':
        return _vistaZona();
      case 'enviando':
        return _vistaEnviando();
      case 'listo':
        return _vistaListo();
    }
    return const SizedBox.shrink();
  }

  Widget _vistaBienvenida() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        const Center(child: CajaIcono(icono: Icons.local_shipping_rounded, tamano: 72)),
        const SizedBox(height: 22),
        _titulo('Bienvenido, conductor', 'Regístrate en Carga Express y comienza el proceso para trabajar con nosotros.'),
        BotonGoogleAuth(obtenerIdToken: widget.obtenerIdToken, onSinCuenta: _usarGoogle),
        const SizedBox(height: 12),
        BotonPrincipalAuth(
          key: const Key('btn_registro_correo'),
          texto: 'Registrarme con correo',
          textoCargando: '',
          cargando: false,
          onPressed: () => setState(() {
            _google = null;
            _idToken = null;
            _error = null;
            _i = 1;
          }),
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

  Widget _vistaPoliticas() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _titulo('Antes de comenzar', 'Lee las condiciones para trabajar con Carga Express.'),
        TarjetaAuth(
          child: Text(politicasConductor.trim(), style: const TextStyle(fontSize: 14, color: AuthColores.texto, height: 1.45)),
        ),
      ],
    );
  }

  Widget _vistaFoto(String titulo, String detalle, _Foto? foto, IconData icono) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _titulo(titulo, detalle),
        TarjetaAuth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: foto == null
                    ? Container(
                        key: const Key('foto_vacia'),
                        height: 200,
                        color: AuthColores.campo,
                        child: Icon(icono, size: 64, color: AuthColores.borde),
                      )
                    : Image.memory(foto.bytes, key: const Key('foto_previa'), height: 220, fit: BoxFit.cover, gaplessPlayback: true),
              ),
              const SizedBox(height: 14),
              BotonSecundario(
                key: const Key('btn_camara'),
                texto: foto == null ? 'Tomar foto' : 'Tomar otra foto',
                icono: Icons.photo_camera_outlined,
                onPressed: () => _elegirFoto(ImageSource.camera),
              ),
              const SizedBox(height: 10),
              BotonSecundario(
                key: const Key('btn_galeria'),
                texto: 'Elegir de la galería',
                icono: Icons.photo_library_outlined,
                color: AuthColores.texto,
                colorBorde: AuthColores.borde,
                onPressed: () => _elegirFoto(ImageSource.gallery),
              ),
              if (_error != null) ...[const SizedBox(height: 12), AvisoErrorAuth(mensaje: _error!)],
            ],
          ),
        ),
      ],
    );
  }

  Widget _vistaTipo() {
    return _pantalla('Tipo de vehículo', 'Elige el tipo y dinos cuánta carga puede llevar.', [
      for (final t in tiposVehiculoRegistro) ...[
        OpcionRadio(
          key: Key('tipo_$t'),
          texto: t,
          elegida: _tipoVehiculo == t,
          onTap: () => setState(() => _tipoVehiculo = t),
        ),
        const SizedBox(height: 8),
      ],
      const SizedBox(height: 6),
      _campo('capacidad', label: 'Capacidad de carga', icono: Icons.scale_outlined, ayuda: 'Ejemplo: 500 kg', maxLength: LimitesUsuario.capacidad),
    ]);
  }

  Widget _vistaZona() {
    final zonas = _zonas;
    return _pantalla('¿En qué zona vas a trabajar?', 'Recibirás las solicitudes de esta zona.', [
      if (zonas == null)
        const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()))
      else
        for (final z in zonas) ...[
          OpcionRadio(
            key: Key('zona_${z['clave']}'),
            texto: z['nombre'].toString(),
            elegida: _zona == z['clave'],
            onTap: () => setState(() {
              _zona = z['clave'].toString();
              _error = null;
            }),
          ),
          const SizedBox(height: 8),
        ],
      if (_error != null) ...[const SizedBox(height: 6), AvisoErrorAuth(mensaje: _error!)],
    ]);
  }

  Widget _vistaEnviando() {
    if (_enviando) {
      return Column(
        children: [
          const SizedBox(height: 60),
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text(
            _registrado ? 'Subiendo tus fotos...' : 'Creando tu cuenta...',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AuthColores.texto),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _titulo(
          _registrado ? 'Falta subir tus fotos' : 'No se pudo crear tu cuenta',
          _registrado ? 'Tu cuenta ya quedó creada; solo falta subir las fotos.' : 'Revisa el error e intenta de nuevo.',
        ),
        if (_error != null) AvisoErrorAuth(mensaje: _error!),
        const SizedBox(height: 16),
        BotonPrincipalAuth(key: const Key('btn_reintentar_registro'), texto: 'Reintentar', textoCargando: '', cargando: false, onPressed: _enviar),
        if (!_registrado) ...[
          const SizedBox(height: 8),
          TextButton(onPressed: _atras, child: const Text('Revisar mis datos')),
        ],
      ],
    );
  }

  Widget _vistaListo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        const Center(child: CajaIcono(icono: Icons.check_circle_rounded, color: ColoresApp.verde, tamano: 72)),
        const SizedBox(height: 22),
        _titulo('Registro completado', 'Tu información fue recibida correctamente. Nuestro equipo debe verificar tus datos antes de habilitarte para trabajar.'),
        BotonPrincipalAuth(
          key: const Key('btn_ir_panel'),
          texto: 'Ir al panel',
          textoCargando: '',
          cargando: false,
          onPressed: () => abrirInicioComoRaiz(context, homeScreenFor(HomeDestino.conductor)),
        ),
      ],
    );
  }

  Widget _vistaBorrador() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        const Center(child: CajaIcono(icono: Icons.history_rounded, tamano: 72)),
        const SizedBox(height: 22),
        _titulo('Continúa tu registro', 'Dejaste un registro a medias. Puedes retomarlo donde lo dejaste.'),
        BotonPrincipalAuth(
          key: const Key('btn_continuar_registro'),
          texto: 'Continuar registro',
          textoCargando: '',
          cargando: false,
          onPressed: _continuarBorrador,
        ),
        const SizedBox(height: 8),
        TextButton(key: const Key('btn_empezar_de_nuevo'), onPressed: _empezarDeNuevo, child: const Text('Empezar de nuevo')),
      ],
    );
  }
}
