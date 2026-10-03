import 'package:flutter/material.dart';

import '../../../services/api/http_client.dart' show ApiException;
import '../../../services/api_client.dart';
import '../../../services/google_auth.dart';
import '../../../widgets/error_carga.dart' show mensajeDeError;
import '../../home_by_role.dart';
import '../../shared/ui_compartida.dart' show CajaIcono, ColoresApp;
import '../auth_estilos.dart';
import '../auth_screen.dart';
import 'asistente_registro.dart';
import 'borrador_registro.dart';
import 'pasos_comunes.dart';
import 'politicas_cliente.dart';

/// Clave de SharedPreferences del borrador del registro (sin contraseña ni idToken).
const String claveBorradorRegistroCliente = 'registro_cliente_borrador';

/// Asistente de registro del cliente: una pregunta por pantalla. La cuenta se
/// crea al terminar los datos personales (`POST /api/auth/register`, con
/// `registro_completo=false`); después, con la sesión, se guardan edad y
/// cédula (`PUT /api/users/profile`) y se aceptan las políticas
/// (`aceptaTerminos: true`), que es lo que completa el registro.
///
/// [RegistroClienteScreen.completar] retoma el proceso de una cuenta que ya
/// existe pero entró con `perfilCompleto: false`: lee el perfil y pide solo lo
/// que falta (teléfono, edad, políticas).
class RegistroClienteScreen extends StatefulWidget {
  /// Datos que devolvió el servidor con 404 CUENTA_NO_EXISTE (`google`) y el
  /// idToken con el que se pidieron, cuando se llega desde el login.
  final Map<String, dynamic>? google;
  final String? idToken;

  /// Para pruebas: reemplaza el selector de cuentas de Google.
  final Future<String?> Function()? obtenerIdToken;

  /// Ya hay sesión: solo se completa lo que falta del perfil.
  final bool completar;

  const RegistroClienteScreen({super.key, this.google, this.idToken, this.obtenerIdToken}) : completar = false;

  const RegistroClienteScreen.completar({super.key})
      : google = null,
        idToken = null,
        obtenerIdToken = null,
        completar = true;

  @override
  State<RegistroClienteScreen> createState() => _RegistroClienteScreenState();
}

class _RegistroClienteScreenState extends State<RegistroClienteScreen> with PasosComunesRegistro {
  static const _borradorStore = BorradorRegistro(claveBorradorRegistroCliente);
  static const _pasosPerfil = ['telefono', 'edad', 'cedula'];

  int _i = 0;
  bool _enviando = false;
  bool _registrado = false;
  bool _cargando = true;
  String? _errorCarga;
  Map<String, dynamic>? _borrador;
  /// En modo completar: solo los pasos que faltan.
  List<String> _pasosCompletar = const [];

  List<String> get _pasos => widget.completar
      ? _pasosCompletar
      : [
          'bienvenida',
          ...(google == null ? PasosComunesRegistro.pasosCorreo : PasosComunesRegistro.pasosGoogle),
          'edad', 'cedula', 'politicas', 'listo',
        ];

  String get _paso => _pasos[_i];

  /// Primer paso que ya exige sesión (no se puede volver más atrás).
  int get _primerPostRegistro => widget.completar ? 0 : _pasos.indexOf('edad');

  @override
  bool get cedulaOpcional => true;

  @override
  String get detalleTelefono => 'El conductor te llamará a este número.';

  @override
  void initState() {
    super.initState();
    if (widget.google != null) {
      // Viene del login con Google: directo a confirmar sus datos.
      usarGoogle(widget.google!, widget.idToken);
      _i = 1;
    }
    if (widget.completar) {
      _registrado = true;
      _cargarPerfil();
    } else {
      _leerBorrador();
    }
  }

  // ── Modo completar ──

  Future<void> _cargarPerfil() async {
    setState(() {
      _cargando = true;
      _errorCarga = null;
    });
    try {
      final p = await ApiClient.instance.getProfile();
      if (!mounted) return;
      final telefono = (p['telefono'] ?? '').toString().trim();
      final edad = p['edad'];
      ctrl('telefono').text = telefono;
      if (edad != null) ctrl('edad').text = edad.toString();
      ctrl('cedula').text = (p['cedula'] ?? '').toString();
      final pasos = [
        if (telefono.isEmpty) 'telefono',
        if (edad == null) ...['edad', 'cedula'],
        if (p['registroCompleto'] != true) 'politicas',
      ];
      if (pasos.isEmpty) {
        // Ya estaba todo: la marca local quedó vieja.
        await ApiClient.instance.marcarPerfilCompleto();
        if (mounted) abrirInicioComoRaiz(context, homeScreenFor(HomeDestino.cliente));
        return;
      }
      setState(() {
        _pasosCompletar = [...pasos, 'listo'];
        _cargando = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorCarga = mensajeDeError(e);
          _cargando = false;
        });
      }
    }
  }

  Future<void> _usarOtraCuenta() async {
    setState(() => _enviando = true);
    await ApiClient.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const AuthScreen()), (_) => false);
  }

  // ── Google ──

  void _usarGoogle(Map<String, dynamic> datos, String? token) {
    setState(() {
      usarGoogle(datos, token);
      _i = 1;
    });
  }

  Future<String?> _tokenGoogle() => (widget.obtenerIdToken ?? idTokenDeGoogle)();

  // ── Borrador ──

  Future<void> _leerBorrador() async {
    final b = await _borradorStore.leer();
    if (!mounted) return;
    setState(() {
      _cargando = false;
      _borrador = widget.google == null ? b : null;
    });
  }

  Future<void> _guardarBorrador() async {
    if (_i < 1 || _registrado) return;
    await _borradorStore.guardar({
      'metodo': google == null ? 'correo' : 'google',
      'paso': _paso,
      'campos': {for (final p in PasosComunesRegistro.camposBorrador) p: ctrl(p).text},
      'google': google,
    });
  }

  void _continuarBorrador() {
    final b = _borrador!;
    final campos = (b['campos'] as Map?) ?? {};
    for (final p in PasosComunesRegistro.camposBorrador) {
      ctrl(p).text = (campos[p] ?? '').toString();
    }
    final g = b['google'];
    google = b['metodo'] == 'google' && g is Map ? Map<String, dynamic>.from(g) : null;
    // Primer paso incompleto antes de crear la cuenta (la contraseña nunca se guarda).
    final pasos = _pasos;
    var destino = 1;
    for (var k = 1; k < pasos.indexOf('edad'); k++) {
      destino = k;
      if (validarComun(pasos[k]) != null) break;
    }
    setState(() {
      _borrador = null;
      error = null;
      _i = destino;
    });
  }

  Future<void> _empezarDeNuevo() async {
    await _borradorStore.borrar();
    if (mounted) setState(() => _borrador = null);
  }

  // ── Navegación ──

  @override
  void siguiente() {
    if (_enviando) return;
    final paso = _paso;
    final e = validarComun(paso);
    if (e != null) {
      setState(() => error = e);
      return;
    }
    FocusScope.of(context).unfocus();
    if (!_registrado && _pasos[_i + 1] == 'edad') {
      _crearCuenta();
    } else if (_registrado && _pasosPerfil.contains(paso) && !_pasosPerfil.contains(_pasos[_i + 1])) {
      _guardarPerfil();
    } else if (paso == 'politicas') {
      _aceptarPoliticas();
    } else {
      setState(() {
        error = null;
        _i++;
      });
      _guardarBorrador();
    }
  }

  bool get _sinVolver => _enviando || _paso == 'listo' || _borrador != null || (_registrado && _i <= _primerPostRegistro);

  void _atras() {
    if (_sinVolver) return;
    if (_i == 0) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      error = null;
      _i--;
    });
  }

  // ── Servidor ──

  Future<void> _avanzarTras(Future<void> Function() accion, {String? Function(ApiException e)? pasoDelError}) async {
    setState(() {
      error = null;
      _enviando = true;
    });
    try {
      await accion();
      if (!mounted) return;
      setState(() => _i++);
      if (_paso == 'listo') await ApiClient.instance.marcarPerfilCompleto();
    } on ApiException catch (e) {
      if (!mounted) return;
      final paso = pasoDelError?.call(e);
      setState(() {
        error = e.message;
        if (paso != null) _i = _pasos.indexOf(paso);
      });
    } catch (e) {
      if (mounted) setState(() => error = mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Map<String, dynamic> _cuerpoRegistro() => {
        'nombre': texto('nombre'),
        'apellido': texto('apellido'),
        'email': texto('email'),
        if (google == null) 'password': ctrl('password').text else 'idToken': idToken,
        'rol': 'cliente',
        'telefono': texto('telefono'),
      };

  Future<void> _crearCuenta() => _avanzarTras(() async {
        if (google != null && idToken == null) {
          // Borrador con Google: el idToken nunca se guarda, se pide otra vez.
          idToken = await _tokenGoogle();
          if (idToken == null) throw Exception('Necesitamos confirmar tu cuenta de Google para continuar.');
        }
        try {
          await ApiClient.instance.register(_cuerpoRegistro());
        } on ApiException catch (e) {
          if (e.statusCode != 401 || google == null) rethrow;
          // El idToken venció mientras llenaba el formulario: uno nuevo y un solo reintento.
          idToken = await _tokenGoogle();
          if (idToken == null) rethrow;
          await ApiClient.instance.register(_cuerpoRegistro());
        }
        if (!mounted) {
          await ApiClient.instance.logout();
          return;
        }
        _registrado = true;
        await _borradorStore.borrar();
      }, pasoDelError: (e) => e.code == 'EMAIL_DUPLICADO' ? (google == null ? 'email' : 'resumen') : null);

  Future<void> _guardarPerfil() => _avanzarTras(() => ApiClient.instance.updateProfile({
        if (widget.completar && _pasos.contains('telefono')) 'telefono': texto('telefono'),
        if (_pasos.contains('edad')) 'edad': int.parse(texto('edad')),
        if (texto('cedula').isNotEmpty) 'cedula': texto('cedula'),
      }));

  Future<void> _aceptarPoliticas() => _avanzarTras(() => ApiClient.instance.updateProfile({'aceptaTerminos': true}));

  // ── UI ──

  @override
  Widget build(BuildContext context) {
    if (_errorCarga != null) return _pantallaErrorCarga();
    final paso = _cargando ? '' : _paso;
    // En modo completar no hay bienvenida: el primer paso ya es una pregunta.
    final pregunta = !_cargando && (_i >= 1 || widget.completar) && paso != 'listo';
    final sinVolver = _cargando || _sinVolver;
    return AsistenteRegistro(
      claveVista: _borrador != null ? 'borrador' : paso,
      cargando: _cargando,
      sinVolver: sinVolver,
      canPop: _i == 0 && !sinVolver,
      onAtras: _atras,
      progreso: pregunta && !widget.completar ? _i / _pasos.indexOf('listo') : null,
      textoBoton: !pregunta || _borrador != null
          ? null
          : paso == 'politicas'
              ? 'Aceptar y continuar'
              : !_registrado && _pasos[_i + 1] == 'edad'
                  ? 'Crear cuenta'
                  : 'Continuar',
      textoBotonCargando: _registrado ? 'Guardando...' : 'Creando tu cuenta...',
      botonCargando: _enviando,
      onContinuar: siguiente,
      child: _cargando
          ? const SizedBox.shrink()
          : _borrador != null
              ? vistaBorradorRegistro(onContinuar: _continuarBorrador, onEmpezarDeNuevo: _empezarDeNuevo)
              : _contenido(paso),
    );
  }

  Widget _contenido(String paso) {
    switch (paso) {
      case 'bienvenida':
        return vistaBienvenidaRegistro(
          icono: Icons.inventory_2_outlined,
          titulo: 'Bienvenido a Carga Express',
          detalle: 'Crea tu cuenta y envía tu carga con conductores de tu zona.',
          obtenerIdToken: widget.obtenerIdToken,
          onGoogle: _usarGoogle,
          onCorreo: () => setState(() {
            google = null;
            idToken = null;
            error = null;
            _i = 1;
          }),
        );
      case 'politicas':
        return vistaPoliticasRegistro('Antes de empezar', 'Lee las condiciones para usar Carga Express.', politicasCliente);
      case 'listo':
        return _vistaListo();
    }
    final comun = contenidoComun(paso) ?? const SizedBox.shrink();
    if (!(_registrado && _i == _primerPostRegistro)) return comun;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        comun,
        const SizedBox(height: 8),
        TextButton(
          key: const Key('btn_otra_cuenta'),
          onPressed: _enviando ? null : _usarOtraCuenta,
          child: const Text('Usar otra cuenta'),
        ),
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
        tituloPaso('Registro completado', 'Ya puedes publicar tu primer envío.'),
        BotonPrincipalAuth(
          key: const Key('btn_ir_panel'),
          texto: 'Empezar',
          textoCargando: '',
          cargando: false,
          onPressed: () => abrirInicioComoRaiz(context, homeScreenFor(HomeDestino.cliente)),
        ),
      ],
    );
  }

  Widget _pantallaErrorCarga() {
    return AsistenteRegistro(
      claveVista: 'error_carga',
      sinVolver: true,
      onAtras: () {},
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          tituloPaso('No se pudo cargar tu perfil', 'Necesitamos saber qué te falta para terminar el registro.'),
          AvisoErrorAuth(mensaje: _errorCarga!),
          const SizedBox(height: 16),
          BotonPrincipalAuth(key: const Key('btn_reintentar_perfil'), texto: 'Reintentar', textoCargando: '', cargando: false, onPressed: _cargarPerfil),
          const SizedBox(height: 8),
          TextButton(key: const Key('btn_otra_cuenta'), onPressed: _usarOtraCuenta, child: const Text('Usar otra cuenta')),
        ],
      ),
    );
  }
}
