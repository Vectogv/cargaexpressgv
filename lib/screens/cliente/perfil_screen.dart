import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../contracts/calificacion.dart';
import '../../contracts/validacion_usuario.dart';
import '../../services/api_client.dart';
import '../../services/api/http_client.dart' show ApiException;
import '../../services/api/payment_service.dart';
import '../../widgets/media_image.dart';
import '../shared/accesos_perfil.dart';
import '../shared/ui_compartida.dart';
import '../user/auth_estilos.dart';
import '../user/auth_screen.dart';
import 'ajustes_screen.dart';
import 'empresa/mi_empresa_screen.dart';
import 'empresa/registrar_empresa_screen.dart';
import 'empresa/unirse_empresa_dialog.dart';
import 'pagos_screen.dart';

/// Portada del perfil, elegida en "Editar perfil" y guardada solo en el
/// celular (no hay campo para esto en el servidor).
const _clavePortada = 'portada_perfil_cliente';
const Map<String, String> portadasPerfil = {
  'ruta': 'Ruta',
  'ciudad': 'Ciudad Blanca',
  'volcan': 'Puracé',
  'liso': 'Azul',
};

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  Map<String, dynamic>? _profile;
  bool _loading = true;
  String? _error;
  int _totalViajes = 0;
  int _completados = 0;
  int _cancelados = 0;
  // Pagos sólo aparece si hay deuda (GET /api/payments), igual que en el inicio.
  bool _tieneDeuda = false;
  bool _suspendidoPorPago = false;
  String _portada = 'ruta';

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadDeuda();
    _cargarPortada();
  }

  Future<void> _cargarPortada() async {
    final prefs = await SharedPreferences.getInstance();
    final valor = prefs.getString(_clavePortada);
    if (mounted && portadasPerfil.containsKey(valor)) setState(() => _portada = valor!);
  }

  /// Si falla, Pagos queda oculto (no se bloquea el perfil).
  Future<void> _loadDeuda() async {
    try {
      final info = await PaymentService.getDebtInfo();
      if (mounted) {
        setState(() {
          _tieneDeuda = tieneDeudaPendiente(info);
          _suspendidoPorPago = cuentaSuspendidaPorPago(info);
        });
      }
    } catch (_) {}
  }

  void _abrirPagos() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const PagosScreen())).then((_) {
      if (mounted) _loadDeuda();
    });
  }

  Future<void> _loadProfile() async {
    try {
      // Envíos/Completados/Cancelados salen de contar el historial: el
      // servidor no expone esos totales por separado.
      final resultados = await Future.wait([
        ApiClient.instance.getProfile(),
        ApiClient.instance.getTripHistory(limit: 100),
      ]);
      final data = resultados[0] as Map<String, dynamic>;
      final viajes = resultados[1] as List<Map<String, dynamic>>;
      if (mounted) {
        setState(() {
          _profile = data;
          _totalViajes = viajes.length;
          _completados = viajes.where((v) => v['estado'] == 'finalizado').length;
          _cancelados = viajes.where((v) => v['estado'] == 'cancelado').length;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  bool _saliendo = false;

  /// Igual que el inicio: esperar a que se revoque la sesión y se limpien los
  /// tokens antes de ir al login (logout() no lanza y tiene timeout de 5 s).
  Future<void> _logout() async {
    if (_saliendo) return;
    setState(() => _saliendo = true);
    await ApiClient.instance.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const AuthScreen()), (_) => false);
  }

  /// Devuelve la URL nueva, o null si se canceló o falló.
  Future<String?> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 75,
    );
    if (picked == null || !mounted) return null;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await picked.readAsBytes();
      // Comprimida a JPEG por image_picker → extensión .jpg.
      final url = await ApiClient.instance.uploadAvatar(bytes, 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg');
      if (mounted && url.isNotEmpty) {
        setState(() { _profile?['avatar'] = url; });
        messenger.showSnackBar(const SnackBar(content: Text('Foto actualizada')));
        return url;
      }
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: ${e.toString().replaceFirst("Exception: ", "")}')));
    }
    return null;
  }

  /// La pantalla de edición guarda por su cuenta (así puede mostrar
  /// "Guardando..." y un error sin perder lo escrito) y devuelve la portada
  /// elegida si tuvo éxito, o null si se canceló.
  Future<void> _editInfo() async {
    final portada = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => _EditarPerfilScreen(
          perfil: _profile ?? const {},
          portadaInicial: _portada,
          cambiarFoto: _pickAvatar,
        ),
      ),
    );
    if (portada == null || !mounted) return;
    setState(() => _portada = portada);
    await _loadProfile();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perfil actualizado')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Íconos claros solo cuando se ve la portada oscura (no en carga/error).
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _loading || _error != null ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
      child: Scaffold(
      backgroundColor: ColoresApp.fondo,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? SafeArea(child: _buildError())
              : RefreshIndicator(
                  onRefresh: () => Future.wait([_loadProfile(), _loadDeuda()]),
                  child: ListView(
                    padding: EdgeInsets.zero,
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      _buildHeader(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildStatsCard(),
                            const SizedBox(height: 16),
                            _buildListaCard(),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 48,
                              child: TextButton(
                                onPressed: _saliendo ? null : _logout,
                                style: TextButton.styleFrom(
                                  foregroundColor: ColoresApp.rojoSesion,
                                  textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('Cerrar sesión'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56, color: ColoresApp.chevron),
            const SizedBox(height: 12),
            const Text('No pudimos cargar tu perfil', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: ColoresApp.textoOscuro)),
            const SizedBox(height: 6),
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: ColoresApp.textoSecundario)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                setState(() { _error = null; _loading = true; });
                _loadProfile();
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final nombre = '${_profile?['nombre'] ?? ApiClient.instance.nombre ?? ''} ${_profile?['apellido'] ?? ''}'.trim();
    final email = _profile?['email'] as String? ?? ApiClient.instance.email ?? '';
    final telefono = _profile?['telefono'] as String?;
    const secundario = TextStyle(fontSize: 14, color: ColoresApp.textoSecundario, fontFeatures: cifrasTabulares);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: ColoresApp.borde)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              SizedBox(height: 112 + MediaQuery.paddingOf(context).top, width: double.infinity, child: PortadaPerfil(id: _portada)),
              if (Navigator.canPop(context))
                Positioned(
                  top: MediaQuery.paddingOf(context).top + 4,
                  left: 4,
                  child: IconButton(
                    tooltip: 'Volver',
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 56,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: 0,
                        top: -36,
                        child: GestureDetector(onTap: _pickAvatar, child: _AvatarConBorde(perfil: _profile, nombre: nombre)),
                      ),
                      Positioned(right: 0, top: 4, child: OutlinedButton.icon(
                      onPressed: _editInfo,
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Editar perfil'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ColoresApp.textoOscuro,
                        minimumSize: const Size(0, 40),
                        side: const BorderSide(color: ColoresApp.bordeCampo),
                        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    )),
                    ],
                  ),
                ),
                Text(
                  nombre.isNotEmpty ? nombre : 'Cliente',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: ColoresApp.textoOscuro, letterSpacing: -0.2),
                ),
                const SizedBox(height: 4),
                Text(email, style: secundario),
                if (telefono != null && telefono.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(telefono, style: secundario),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Total, calificación real (promedio que calcula el servidor en
  /// POST /api/trips/:id/rate; "Nuevo" sin viajes calificados) y una barra
  /// proporcional de completados/cancelados.
  Widget _buildStatsCard() {
    final calificacion = etiquetaCalificacion(_profile?['calificacion'], totalViajes: _totalViajes).replaceAll('.', ',');
    const cifra = TextStyle(fontFeatures: cifrasTabulares);
    return TarjetaBlanca(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('$_totalViajes',
                  style: cifra.copyWith(fontSize: 32, fontWeight: FontWeight.w700, color: ColoresApp.textoOscuro, letterSpacing: -0.5)),
              const SizedBox(width: 8),
              const Expanded(child: Text('envíos en total', style: TextStyle(fontSize: 15, color: ColoresApp.textoSecundario))),
              const Icon(Icons.star_rounded, size: 18, color: ColoresApp.estrella),
              const SizedBox(width: 4),
              Text(calificacion, style: cifra.copyWith(fontSize: 15, fontWeight: FontWeight.w600, color: ColoresApp.textoOscuro)),
              const SizedBox(width: 4),
              const Text('calificación', style: TextStyle(fontSize: 13, color: ColoresApp.textoSecundario)),
            ],
          ),
          const SizedBox(height: 14),
          Semantics(
            label: '$_completados completados y $_cancelados cancelados de $_totalViajes envíos',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 8,
                child: _completados + _cancelados == 0
                    ? const ColoredBox(color: ColoresApp.divisor)
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_completados > 0) Expanded(flex: _completados, child: const ColoredBox(color: ColoresApp.azul)),
                          if (_completados > 0 && _cancelados > 0) const SizedBox(width: 2),
                          if (_cancelados > 0) Expanded(flex: _cancelados, child: const ColoredBox(color: ColoresApp.naranja)),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _leyenda(ColoresApp.azul, _completados, 'completados'),
              const SizedBox(width: 20),
              _leyenda(ColoresApp.naranja, _cancelados, 'cancelados'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _leyenda(Color color, int valor, String texto) => Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 6),
          Text.rich(TextSpan(
            style: const TextStyle(fontSize: 13, color: ColoresApp.textoSecundario),
            children: [
              TextSpan(
                  text: '$valor',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: ColoresApp.textoOscuro, fontFeatures: cifrasTabulares)),
              TextSpan(text: ' $texto'),
            ],
          )),
        ],
      );

  Widget _buildListaCard() {
    final filas = <Widget>[
      if (_tieneDeuda)
        _fila(Icons.credit_card, 'Pagos', _abrirPagos, destacado: _suspendidoPorPago ? 'Pendiente' : null),
      if (_profile?['empresa'] is Map)
        _fila(Icons.business_outlined, 'Mi empresa', () async {
          await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const MiEmpresaScreen()));
          if (mounted) _loadProfile();
        })
      else if (_profile != null) ...[
        _fila(Icons.add_business_outlined, 'Registrar mi empresa', () async {
          final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const RegistrarEmpresaScreen()));
          if (mounted && ok == true) _loadProfile();
        }),
        _fila(Icons.group_add_outlined, 'Unirme a una empresa', () async {
          if (await mostrarUnirseEmpresa(context) && mounted) _loadProfile();
        }),
      ],
      _fila(Icons.settings_outlined, 'Ajustes',
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AjustesScreen()))),
      _fila(Icons.emergency_outlined, 'Número de emergencia', () async {
        if (await mostrarDialogoEmergencia(context, _profile, obligatorio: false)) _loadProfile();
      }),
      _fila(Icons.info_outline, 'Acerca de nosotros', () => mostrarAcercaDe(context)),
    ];
    return TarjetaBlanca(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < filas.length; i++) ...[
            if (i > 0) const Divider(height: 1, thickness: 1, color: ColoresApp.divisor),
            filas[i],
          ],
        ],
      ),
    );
  }

  Widget _fila(IconData icon, String label, VoidCallback onTap, {String? destacado}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(icon, size: 20, color: ColoresApp.textoSecundario),
              const SizedBox(width: 14),
              Expanded(
                  child: Text(label,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: ColoresApp.textoOscuro))),
              if (destacado != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: ColoresApp.naranjaFondo, borderRadius: BorderRadius.circular(8)),
                  child: Text(destacado,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ColoresApp.naranjaTexto)),
                )
              else
                const Icon(Icons.chevron_right, size: 20, color: ColoresApp.chevron),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarConBorde extends StatelessWidget {
  final Map<String, dynamic>? perfil;
  final String nombre;
  final double radio;
  const _AvatarConBorde({required this.perfil, required this.nombre, this.radio = 40});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)),
      child: MediaAvatar(
        path: perfil?['avatar'] as String?,
        name: nombre,
        radius: radio - 4,
        backgroundColor: ColoresApp.textoOscuro,
        foregroundColor: Colors.white,
        fontSize: radio * 0.6,
      ),
    );
  }
}

/// Dibujo de la portada (viewBox 390x120 de la maqueta, recortado para
/// cubrir, como `preserveAspectRatio="xMidYMid slice"`).
class PortadaPerfil extends StatelessWidget {
  final String id;
  const PortadaPerfil({super.key, required this.id});

  @override
  Widget build(BuildContext context) =>
      ClipRect(child: CustomPaint(painter: _PortadaPainter(id), size: Size.infinite));
}

class _PortadaPainter extends CustomPainter {
  final String id;
  _PortadaPainter(this.id);

  static const _fondos = {
    'ruta': Color(0xFF16325C),
    'ciudad': Color(0xFF23487A),
    'volcan': Color(0xFF2F5585),
    'liso': ColoresApp.azul,
  };

  @override
  void paint(Canvas canvas, Size size) {
    final fondo = _fondos[id] ?? _fondos['ruta']!;
    canvas.drawRect(Offset.zero & size, Paint()..color = fondo);
    final s = math.max(size.width / 390, size.height / 120);
    canvas.save();
    canvas.translate((size.width - 390 * s) / 2, (size.height - 120 * s) / 2);
    canvas.scale(s);
    Paint blanco(double a) => Paint()..color = Colors.white.withValues(alpha: a);
    Paint trazo(double a, double w) => blanco(a)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round;
    Path poli(List<double> p) {
      final path = Path()..moveTo(p[0], p[1]);
      for (var i = 2; i < p.length; i += 2) {
        path.lineTo(p[i], p[i + 1]);
      }
      return path..close();
    }

    switch (id) {
      case 'ciudad':
        final arcos = Path();
        for (final x in <double>[0, 48, 96, 144, 252, 300, 348]) {
          arcos
            ..moveTo(x, 120)
            ..lineTo(x, 84)
            ..arcToPoint(Offset(x + 36, 84), radius: const Radius.circular(18))
            ..lineTo(x + 36, 120)
            ..close();
        }
        canvas.drawPath(arcos, blanco(0.16));
        canvas.drawPath(poli([196, 120, 196, 44, 216, 26, 236, 44, 236, 120]), blanco(0.24));
        canvas.drawCircle(const Offset(216, 56), 7, trazo(0.5, 2));
      case 'volcan':
        canvas.drawPath(poli([0, 120, 90, 72, 150, 94, 232, 36, 300, 88, 390, 62, 390, 120]), Paint()..color = const Color(0xFF1E3D66));
        canvas.drawPath(poli([218, 46, 232, 36, 246, 46]), blanco(0.7));
        canvas.drawPath(poli([0, 120, 120, 96, 200, 110, 290, 86, 390, 104, 390, 120]), Paint()..color = const Color(0xFF132B4B));
      case 'liso':
        break;
      default:
        final rejilla = trazo(0.07, 10)..strokeCap = StrokeCap.butt;
        for (final y in <double>[30, 75]) {
          canvas.drawLine(Offset(0, y), Offset(390, y), rejilla);
        }
        for (final x in <double>[70, 185, 300]) {
          canvas.drawLine(Offset(x, 0), Offset(x, 120), rejilla);
        }
        final curva = Path()
          ..moveTo(30, 92)
          ..cubicTo(80, 92, 95, 40, 160, 44)
          ..cubicTo(225, 48, 255, 98, 315, 62)
          ..cubicTo(375, 26, 370, 28, 392, 30);
        final punteada = Path();
        for (final m in curva.computeMetrics()) {
          for (double d = 0; d < m.length; d += 14) {
            punteada.addPath(m.extractPath(d, math.min(d + 7, m.length)), Offset.zero);
          }
        }
        canvas.drawPath(punteada, trazo(0.6, 2.5));
        canvas.drawCircle(const Offset(30, 92), 6, Paint()..color = fondo);
        canvas.drawCircle(const Offset(30, 92), 6, trazo(1, 2.5));
        canvas.drawCircle(const Offset(330, 52), 6, blanco(1));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PortadaPainter old) => old.id != id;
}

/// Pantalla de edición del perfil. Guarda por su cuenta (PUT
/// /api/users/profile) y devuelve la portada elegida si tuvo éxito, o null
/// si se canceló.
class _EditarPerfilScreen extends StatefulWidget {
  final Map<String, dynamic> perfil;
  final String portadaInicial;
  final Future<String?> Function() cambiarFoto;
  const _EditarPerfilScreen({required this.perfil, required this.portadaInicial, required this.cambiarFoto});

  @override
  State<_EditarPerfilScreen> createState() => _EditarPerfilScreenState();
}

class _EditarPerfilScreenState extends State<_EditarPerfilScreen> {
  late final _nombre = _ctrl('nombre');
  late final _apellido = _ctrl('apellido');
  late final _email = _ctrl('email');
  late final _telefono = _ctrl('telefono');
  late final _contactoNombre = _ctrl('contactoEmergenciaNombre');
  late final _contactoTelefono = _ctrl('contactoEmergenciaTelefono');

  late String _portada = widget.portadaInicial;
  late final Map<String, dynamic> _perfil = Map.of(widget.perfil);
  String? _errorTelefono;
  String? _errorContactoTelefono;
  String? _errorGeneral;
  bool _guardando = false;

  TextEditingController _ctrl(String campo) =>
      TextEditingController(text: widget.perfil[campo]?.toString() ?? '');

  @override
  void dispose() {
    for (final c in [_nombre, _apellido, _email, _telefono, _contactoNombre, _contactoTelefono]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _seccion(String titulo, {String? detalle, required List<Widget> hijos}) => Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(titulo, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: ColoresApp.textoOscuro)),
            if (detalle != null) ...[
              const SizedBox(height: 2),
              Text(detalle, style: const TextStyle(fontSize: 13, color: ColoresApp.textoSecundario)),
            ],
            const SizedBox(height: 12),
            ...hijos,
          ],
        ),
      );

  Widget _campo(TextEditingController c, String label, int max,
      {TextInputType tipo = TextInputType.text, String? error, bool enabled = true, String? ayuda}) {
    OutlineInputBorder borde(Color color, [double ancho = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: color, width: ancho));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: ColoresApp.etiquetaCampo)),
        const SizedBox(height: 6),
        TextField(
          key: ValueKey('campo_$label'),
          controller: c,
          keyboardType: tipo,
          enabled: enabled && !_guardando,
          inputFormatters: [LengthLimitingTextInputFormatter(max)],
          style: TextStyle(fontSize: 15, color: enabled ? ColoresApp.textoOscuro : ColoresApp.textoSecundario),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: enabled ? Colors.white : ColoresApp.fondo,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            enabledBorder: borde(ColoresApp.bordeCampo),
            disabledBorder: borde(ColoresApp.borde),
            focusedBorder: borde(ColoresApp.azul, 2),
            errorBorder: borde(ColoresApp.rojoSesion),
            focusedErrorBorder: borde(ColoresApp.rojoSesion, 2),
            errorText: error,
            helperText: ayuda,
            helperStyle: const TextStyle(fontSize: 12, color: ColoresApp.textoSecundario),
          ),
        ),
      ],
    );
  }

  Widget _selectorPortada() {
    final nombre = '${_nombre.text} ${_apellido.text}'.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: ColoresApp.borde),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 88, width: double.infinity, child: PortadaPerfil(id: _portada)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 8, 0),
                  child: SizedBox(
                    height: 48,
                    child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: 0,
                        top: -28,
                        child: _AvatarConBorde(perfil: _perfil, nombre: nombre, radio: 32),
                      ),
                      Positioned(right: 0, top: 4, child: TextButton.icon(
                        onPressed: _guardando
                            ? null
                            : () async {
                                final url = await widget.cambiarFoto();
                                if (url != null && mounted) setState(() => _perfil['avatar'] = url);
                              },
                        icon: const Icon(Icons.photo_camera_outlined, size: 18),
                        label: const Text('Cambiar foto'),
                        style: TextButton.styleFrom(
                          foregroundColor: ColoresApp.azul,
                          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      )),
                    ],
                  ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (final e in portadasPerfil.entries) ...[
              if (e.key != portadasPerfil.keys.first) const SizedBox(width: 8),
              Expanded(child: _miniatura(e.key, e.value)),
            ],
          ],
        ),
      ],
    );
  }

  Widget _miniatura(String id, String etiqueta) {
    final elegida = id == _portada;
    return Semantics(
      button: true,
      selected: elegida,
      label: 'Portada $etiqueta',
      child: GestureDetector(
        key: ValueKey('portada_$id'),
        onTap: _guardando ? null : () => setState(() => _portada = id),
        child: Column(
          children: [
            Container(
              height: 52,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: elegida ? ColoresApp.azul : Colors.transparent, width: 2),
              ),
              child: ClipRRect(borderRadius: BorderRadius.circular(7), child: PortadaPerfil(id: id)),
            ),
            const SizedBox(height: 6),
            Text(
              etiqueta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: elegida ? FontWeight.w600 : FontWeight.w500,
                color: elegida ? ColoresApp.azul : ColoresApp.textoSecundario,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _guardar() async {
    final errorTelefono = validarTelefono(_telefono.text);
    final errorContacto = validarTelefono(_contactoTelefono.text, opcional: true);
    if (errorTelefono != null || errorContacto != null) {
      setState(() {
        _errorTelefono = errorTelefono;
        _errorContactoTelefono = errorContacto;
      });
      return;
    }
    setState(() {
      _guardando = true;
      _errorGeneral = null;
      _errorTelefono = null;
      _errorContactoTelefono = null;
    });
    try {
      await ApiClient.instance.updateProfile(cuerpoActualizacionPerfil(
        nombre: _nombre.text,
        apellido: _apellido.text,
        telefono: _telefono.text,
        contactoNombre: _contactoNombre.text,
        contactoTelefono: _contactoTelefono.text,
      ));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_clavePortada, _portada);
      if (!mounted) return;
      Navigator.pop(context, _portada);
    } on ApiException catch (e) {
      setState(() {
        _guardando = false;
        _errorGeneral = e.message;
      });
    } catch (e) {
      setState(() {
        _guardando = false;
        _errorGeneral = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_guardando,
      child: Scaffold(
        backgroundColor: ColoresApp.fondo,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          foregroundColor: ColoresApp.textoOscuro,
          elevation: 0,
          scrolledUnderElevation: 0,
          shape: const Border(bottom: BorderSide(color: ColoresApp.borde)),
          title: const Text('Editar perfil', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          children: [
            _seccion('Portada', hijos: [_selectorPortada()]),
            _seccion('Datos personales', hijos: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _campo(_nombre, 'Nombre', LimitesUsuario.nombre)),
                  const SizedBox(width: 12),
                  Expanded(child: _campo(_apellido, 'Apellido', LimitesUsuario.apellido)),
                ],
              ),
            ]),
            _seccion('Contacto', hijos: [
              _campo(_email, 'Correo', LimitesUsuario.email,
                  tipo: TextInputType.emailAddress, enabled: false, ayuda: 'Para cambiarlo, escribe a soporte.'),
              const SizedBox(height: 14),
              _campo(_telefono, 'Teléfono', LimitesUsuario.telefono, tipo: TextInputType.phone, error: _errorTelefono),
            ]),
            _seccion('Contacto de emergencia', detalle: 'Opcional. Lo llamamos solo si activas el SOS.', hijos: [
              _campo(_contactoNombre, 'Nombre del contacto', LimitesUsuario.contactoNombre),
              const SizedBox(height: 14),
              _campo(_contactoTelefono, 'Teléfono del contacto', LimitesUsuario.contactoTelefono,
                  tipo: TextInputType.phone, error: _errorContactoTelefono),
            ]),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: ColoresApp.borde)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_errorGeneral != null) ...[
                    AvisoErrorAuth(mensaje: _errorGeneral!),
                    const SizedBox(height: 10),
                  ],
                  BotonPrincipal(
                    texto: _guardando ? 'Guardando…' : 'Guardar cambios',
                    onPressed: _guardando ? null : _guardar,
                    color: ColoresApp.azul,
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
