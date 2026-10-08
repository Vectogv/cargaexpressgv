import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../contracts/validacion_usuario.dart';
import '../../../services/api/coverage_service.dart';
import '../../../services/api/http_client.dart' show ApiException;
import '../../../services/api_client.dart';
import '../../../services/google_auth.dart';
import '../../../widgets/error_carga.dart' show mensajeDeError;
import '../../home_by_role.dart';
import '../../shared/ui_compartida.dart' show BotonSecundario, CajaIcono, ColoresApp, OpcionRadio;
import '../auth_estilos.dart';
import '../registro/asistente_registro.dart';
import '../registro/borrador_registro.dart';
import '../registro/pasos_comunes.dart';
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

class _RegistroConductorScreenState extends State<RegistroConductorScreen> with PasosComunesRegistro {
  static const _conBorrador = [...PasosComunesRegistro.camposBorrador, 'modelo', 'placa', 'capacidad', 'codigoReferido'];
  static const _borradorStore = BorradorRegistro(claveBorradorRegistroConductor);

  int _i = 0;
  String _tipoVehiculo = tiposVehiculoRegistro.first;
  String? _zona;
  List<Map<String, dynamic>>? _zonas;
  /// Fotos por paso (ver [_pasosFoto]); [_vence] solo para tecnomecánica y SOAT.
  final Map<String, _Foto> _fotos = {};
  final Map<String, String> _vence = {};
  final Set<String> _subidas = {};
  bool _enviando = false;
  bool _registrado = false;
  /// null: aún no se leyó SharedPreferences; vacío: sin borrador.
  Map<String, dynamic>? _borrador;
  bool _borradorLeido = false;

  List<String> get _pasos => [
        'bienvenida',
        'politicas',
        ...(google == null ? PasosComunesRegistro.pasosCorreo : PasosComunesRegistro.pasosGoogle),
        'edad', 'cedula', 'foto_conductor', 'licencia', 'modelo', 'tipo', 'placa', 'foto_vehiculo',
        'tarjeta_propiedad', 'tecnomecanica', 'soat', 'zona', 'enviando', 'listo',
      ];

  /// Documentos con foto que exige el servidor para aprobar (ya no la foto de la cédula).
  static const _pasosFoto = ['foto_conductor', 'licencia', 'foto_vehiculo', 'tarjeta_propiedad', 'tecnomecanica', 'soat'];
  static const _conVence = ['tecnomecanica', 'soat'];
  static const _textoFoto = {
    'foto_conductor': ('Ahora necesitamos conocerte', 'Sube una foto tuya para validar tu identidad.', Icons.person_outline_rounded),
    'licencia': ('Licencia de conducción', 'Que se lean bien tus datos y la categoría.', Icons.credit_card_outlined),
    'foto_vehiculo': ('Foto del vehículo', 'Que se vea completo y con la placa legible.', Icons.local_shipping_outlined),
    'tarjeta_propiedad': ('Tarjeta de propiedad', 'La del vehículo que registraste.', Icons.description_outlined),
    'tecnomecanica': ('Revisión técnico-mecánica', 'Sube el certificado vigente y su fecha de vencimiento.', Icons.build_outlined),
    'soat': ('SOAT', 'Sube el SOAT vigente y su fecha de vencimiento. Si no tienes, podrás pedir una excepción desde Documentos.', Icons.health_and_safety_outlined),
  };

  String get _paso => _pasos[_i];

  @override
  String get detalleTelefono => 'Los clientes te llamarán a este número.';

  @override
  void initState() {
    super.initState();
    if (widget.google != null) usarGoogle(widget.google!, widget.idToken);
    _leerBorrador();
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
      _borradorLeido = true;
      // Si se llega desde el login con Google, ese dato manda sobre el borrador.
      _borrador = widget.google == null ? b : null;
    });
  }

  Future<void> _guardarBorrador() async {
    if (_i < 2 || _registrado) return;
    await _borradorStore.guardar({
      'metodo': google == null ? 'correo' : 'google',
      'paso': _paso,
      'campos': {for (final p in _conBorrador) p: ctrl(p).text},
      'tipo': _tipoVehiculo,
      'zona': _zona,
      'fotos': {for (final e in _fotos.entries) if (e.value.ruta != null) e.key: e.value.ruta},
      'vence': _vence,
      'google': google,
    });
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
      ctrl(p).text = (campos[p] ?? '').toString();
    }
    final g = b['google'];
    google = b['metodo'] == 'google' && g is Map ? Map<String, dynamic>.from(g) : null;
    _tipoVehiculo = tiposVehiculoRegistro.contains(b['tipo']) ? b['tipo'] as String : _tipoVehiculo;
    _zona = b['zona'] as String?;
    final fotos = (b['fotos'] as Map?) ?? {};
    for (final p in _pasosFoto) {
      final f = await _fotoDesdeRuta(fotos[p]);
      if (f != null) _fotos[p] = f;
    }
    final vence = (b['vence'] as Map?) ?? {};
    for (final p in _conVence) {
      if (vence[p] is String) _vence[p] = vence[p] as String;
    }
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
      error = null;
      _i = destino;
    });
    if (_paso == 'zona') _cargarZonas();
  }

  Future<void> _empezarDeNuevo() async {
    await _borradorStore.borrar();
    if (mounted) setState(() => _borrador = null);
  }

  // ── Validación y navegación ──

  String? _validar(String paso) {
    switch (paso) {
      case 'modelo':
      case 'placa':
        return texto(paso).isEmpty ? 'Este campo es obligatorio' : null;
      case 'tipo':
        return texto('capacidad').isEmpty ? 'Indica la capacidad de carga' : null;
      case 'foto_conductor':
        return _fotos[paso] == null ? 'Sube una foto tuya para continuar' : null;
      case 'foto_vehiculo':
        return _fotos[paso] == null ? 'Sube una foto del vehículo para continuar' : null;
      case 'licencia':
      case 'tarjeta_propiedad':
      case 'tecnomecanica':
      case 'soat':
        if (_fotos[paso] == null) return 'Sube la foto del documento para continuar';
        return _conVence.contains(paso) && _vence[paso] == null ? 'Indica la fecha de vencimiento' : null;
      case 'zona':
        return _zona == null ? 'Elige la zona donde vas a trabajar' : null;
    }
    return validarComun(paso);
  }

  @override
  void siguiente() {
    final e = _validar(_paso);
    if (e != null) {
      setState(() => error = e);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      error = null;
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
      error = null;
      _i--;
      if (_paso == 'enviando') _i--;
    });
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
      if (mounted) setState(() => error = 'No se pudo abrir la ${origen == ImageSource.camera ? 'cámara' : 'galería'}.');
      return;
    }
    if (foto == null || !mounted) return;
    setState(() {
      error = null;
      _fotos[_paso] = foto!;
      _subidas.remove(_paso);
    });
    _guardarBorrador();
  }

  Future<void> _elegirVence() async {
    final hoy = DateTime.now();
    final fecha = await showDatePicker(
      context: context,
      initialDate: hoy,
      firstDate: hoy,
      lastDate: DateTime(hoy.year + 10),
      helpText: 'Fecha de vencimiento',
    );
    if (fecha == null || !mounted) return;
    setState(() {
      error = null;
      _vence[_paso] = fecha.toIso8601String().substring(0, 10);
      _subidas.remove(_paso);
    });
    _guardarBorrador();
  }

  // ── Alta ──

  Map<String, dynamic> _cuerpo() => {
        'nombre': texto('nombre'),
        'apellido': texto('apellido'),
        'email': texto('email'),
        if (google == null) 'password': ctrl('password').text else 'idToken': idToken,
        'rol': 'conductor',
        'edad': int.parse(texto('edad')),
        'telefono': texto('telefono'),
        'cedula': texto('cedula'),
        'placa': texto('placa').toUpperCase(),
        'tipoVehiculo': _tipoVehiculo,
        'capacidad': texto('capacidad'),
        'ciudad': _zona,
        'modeloVehiculo': texto('modelo'),
        'aceptaTerminos': true,
        if (texto('codigoReferido').isNotEmpty) 'codigoReferido': texto('codigoReferido').toUpperCase(),
      };

  Future<void> _enviar() async {
    setState(() {
      error = null;
      _enviando = true;
    });
    try {
      if (!_registrado) {
        if (google != null && idToken == null) {
          // Borrador con Google: el idToken nunca se guarda, se pide otra vez.
          idToken = await _tokenGoogle();
          if (idToken == null) throw Exception('Necesitamos confirmar tu cuenta de Google para terminar.');
        }
        try {
          await ApiClient.instance.register(_cuerpo());
        } on ApiException catch (e) {
          if (e.statusCode != 401 || google == null) rethrow;
          // El idToken venció mientras llenaba el formulario: uno nuevo y un solo reintento.
          idToken = await _tokenGoogle();
          if (idToken == null) rethrow;
          await ApiClient.instance.register(_cuerpo());
        }
        if (!mounted) {
          await ApiClient.instance.logout();
          return;
        }
        _registrado = true;
        await _borradorStore.borrar();
      }
      final ts = DateTime.now().millisecondsSinceEpoch;
      for (final p in _pasosFoto) {
        if (_subidas.contains(p)) continue;
        final bytes = _fotos[p]!.bytes;
        final nombre = '${p}_$ts.jpg';
        switch (p) {
          case 'foto_conductor':
            await ApiClient.instance.uploadDocumentDriverPhoto(bytes, nombre);
          case 'foto_vehiculo':
            await ApiClient.instance.uploadDocumentVehiculo(bytes, nombre);
          case 'licencia':
            await ApiClient.instance.uploadDocumentLicencia(bytes, nombre);
          default:
            await ApiClient.instance.uploadDocumento(p.replaceAll('_', '-'), bytes, nombre, vence: _vence[p]);
        }
        _subidas.add(p);
      }
      if (mounted) setState(() => _i = _pasos.indexOf('listo'));
    } on ApiException catch (e) {
      if (!mounted) return;
      final paso = _registrado
          ? null
          : switch (e.code) {
              'EMAIL_DUPLICADO' => google == null ? 'email' : 'resumen',
              'PLACA_DUPLICADA' => 'placa',
              'CEDULA_DUPLICADA' => 'cedula',
              'CODIGO_INVALIDO' => 'zona',
              _ => null,
            };
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

  // ── UI ──

  @override
  Widget build(BuildContext context) {
    final paso = _paso;
    final pregunta = _i >= 2 && paso != 'enviando' && paso != 'listo';
    final sinVolver = _enviando || paso == 'listo' || _borrador != null;
    return AsistenteRegistro(
      claveVista: _borrador != null ? 'borrador' : paso,
      cargando: !_borradorLeido,
      sinVolver: sinVolver,
      canPop: _i == 0 && !sinVolver,
      onAtras: _atras,
      progreso: pregunta ? (_i - 1) / (_pasos.indexOf('zona') - 1) : null,
      textoBoton: !(pregunta || paso == 'politicas')
          ? null
          : paso == 'politicas'
              ? 'Aceptar y continuar'
              : paso == 'zona'
                  ? 'Crear mi cuenta'
                  : 'Continuar',
      onContinuar: siguiente,
      child: _borrador != null
          ? vistaBorradorRegistro(onContinuar: _continuarBorrador, onEmpezarDeNuevo: _empezarDeNuevo)
          : _contenido(paso),
    );
  }

  Widget _contenido(String paso) {
    switch (paso) {
      case 'bienvenida':
        return vistaBienvenidaRegistro(
          icono: Icons.local_shipping_rounded,
          titulo: 'Bienvenido, conductor',
          detalle: 'Regístrate en Carga Express y comienza el proceso para trabajar con nosotros.',
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
        return vistaPoliticasRegistro('Antes de comenzar', 'Lee las condiciones para trabajar con Carga Express.', politicasConductor);
      case 'modelo':
        return pantallaPaso('Cuéntanos sobre tu vehículo', '¿Qué marca y modelo es? Ejemplo: Chevrolet NHR 2018.', [
          campo(paso, label: 'Marca y modelo', icono: Icons.directions_car_outlined, capitalizacion: TextCapitalization.words, maxLength: 100),
        ]);
      case 'tipo':
        return _vistaTipo();
      case 'placa':
        return pantallaPaso('Placa del vehículo', 'Como aparece en la tarjeta de propiedad.', [
          campo(paso, label: 'Placa', icono: Icons.pin_outlined, capitalizacion: TextCapitalization.characters, maxLength: LimitesUsuario.placa, ayuda: 'Ejemplo: ABC123'),
        ]);
      case 'zona':
        return _vistaZona();
      case 'enviando':
        return _vistaEnviando();
      case 'listo':
        return _vistaListo();
    }
    if (_textoFoto.containsKey(paso)) return _vistaFoto(paso);
    return contenidoComun(paso) ?? const SizedBox.shrink();
  }

  Widget _vistaFoto(String paso) {
    final (titulo, detalle, icono) = _textoFoto[paso]!;
    final foto = _fotos[paso];
    final vence = _vence[paso];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        tituloPaso(titulo, detalle),
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
              if (_conVence.contains(paso)) ...[
                const SizedBox(height: 10),
                BotonSecundario(
                  key: const Key('btn_vence'),
                  texto: vence == null ? 'Fecha de vencimiento' : 'Vence el ${vence.substring(8, 10)}/${vence.substring(5, 7)}/${vence.substring(0, 4)}',
                  icono: Icons.event_outlined,
                  color: vence == null ? AuthColores.texto : ColoresApp.verde,
                  colorBorde: AuthColores.borde,
                  onPressed: _elegirVence,
                ),
              ],
              if (error != null) ...[const SizedBox(height: 12), AvisoErrorAuth(mensaje: error!)],
            ],
          ),
        ),
      ],
    );
  }

  Widget _vistaTipo() {
    return pantallaPaso('Tipo de vehículo', 'Elige el tipo y dinos cuánta carga puede llevar.', [
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
      campo('capacidad', label: 'Capacidad de carga', icono: Icons.scale_outlined, ayuda: 'Ejemplo: 500 kg', maxLength: LimitesUsuario.capacidad),
    ]);
  }

  Widget _vistaZona() {
    final zonas = _zonas;
    return pantallaPaso('¿En qué zona vas a trabajar?', 'Recibirás las solicitudes de esta zona.', [
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
              error = null;
            }),
          ),
          const SizedBox(height: 8),
        ],
      const SizedBox(height: 8),
      TextField(
        key: const Key('campo_codigo_referido'),
        controller: ctrl('codigoReferido'),
        textCapitalization: TextCapitalization.characters,
        decoration: decoracionCampoAuth(label: 'Código de invitación (opcional)', icono: Icons.person_add_alt_1_outlined),
      ),
      if (error != null) ...[const SizedBox(height: 6), AvisoErrorAuth(mensaje: error!)],
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
        tituloPaso(
          _registrado ? 'Falta subir tus fotos' : 'No se pudo crear tu cuenta',
          _registrado ? 'Tu cuenta ya quedó creada; solo falta subir las fotos.' : 'Revisa el error e intenta de nuevo.',
        ),
        if (error != null) AvisoErrorAuth(mensaje: error!),
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
        tituloPaso('Registro completado', 'Tu información fue recibida correctamente. Nuestro equipo debe verificar tus datos antes de habilitarte para trabajar.'),
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
}
