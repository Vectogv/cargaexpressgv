import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/formato_dinero.dart';
import '../../../core/guardar_descargas.dart';
import '../../../services/api/empresa_service.dart';
import '../../../widgets/error_carga.dart';
import '../../shared/ui_compartida.dart';
import 'registrar_empresa_screen.dart';

/// Estado de mi empresa (GET /api/empresas/mia): el dueño ve código, equipo,
/// resumen del mes y reporte; el empleado, el nombre y "Salir de la empresa".
/// Cierra con `true` si cambió la pertenencia (salió de la empresa).
class MiEmpresaScreen extends StatefulWidget {
  const MiEmpresaScreen({super.key});

  @override
  State<MiEmpresaScreen> createState() => _MiEmpresaScreenState();
}

class _MiEmpresaScreenState extends State<MiEmpresaScreen> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _ocupado = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _error = null);
    try {
      final d = await EmpresaService.mia();
      if (mounted) setState(() => _data = d);
    } catch (e) {
      if (mounted) setState(() => _error = mensajeDeError(e));
    }
  }

  Map<String, dynamic>? get _empresa => (_data?['empresa'] as Map?)?.cast<String, dynamic>();
  List<Map<String, dynamic>> get _miembros => (_data?['miembros'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? const [];
  Map<String, dynamic>? get _resumen => (_data?['resumen'] as Map?)?.cast<String, dynamic>();

  void _aviso(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  Future<bool> _confirmar(String titulo, String cuerpo, String boton) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => DialogoApp(
        icono: Icons.warning_amber_rounded,
        colorIcono: ColoresApp.rojo,
        titulo: titulo,
        cuerpo: cuerpo,
        textoPrincipal: boton,
        colorPrincipal: ColoresApp.rojo,
        onPrincipal: () => Navigator.pop(ctx, true),
        textoSecundario: 'Cancelar',
      ),
    );
    return r == true;
  }

  Future<void> _accion(Future<void> Function() hacer, {String? ok, bool cerrar = false}) async {
    if (_ocupado) return;
    setState(() => _ocupado = true);
    try {
      await hacer();
      if (!mounted) return;
      if (ok != null) _aviso(ok);
      if (cerrar) {
        Navigator.pop(context, true);
        return;
      }
      await _cargar();
    } catch (e) {
      if (mounted) _aviso(mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _salir() async {
    if (!await _confirmar('¿Salir de la empresa?', 'Tus próximos envíos ya no se contarán en el reporte de ${_empresa?['nombre']}.', 'Salir de la empresa')) return;
    await _accion(EmpresaService.salir, ok: 'Saliste de la empresa', cerrar: true);
  }

  Future<void> _quitar(Map<String, dynamic> m) async {
    final nombre = '${m['nombre'] ?? ''} ${m['apellido'] ?? ''}'.trim();
    if (!await _confirmar('¿Quitar a $nombre?', 'Ya no podrá pedir envíos a nombre de la empresa. Los viajes anteriores se conservan en el reporte.', 'Quitar')) return;
    await _accion(() => EmpresaService.quitarMiembro(m['id']), ok: '$nombre salió de la empresa');
  }

  Future<void> _corregir() async {
    final ok = await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => RegistrarEmpresaScreen(inicial: _empresa)));
    if (ok == true && mounted) {
      _aviso('Enviamos tu empresa a revisión');
      await _cargar();
    }
  }

  String get _codigo => '${_empresa?['codigo'] ?? ''}';

  Future<void> _copiar() async {
    await Clipboard.setData(ClipboardData(text: _codigo));
    if (mounted) _aviso('Código copiado');
  }

  Future<void> _compartir() {
    final texto = 'Únete a ${_empresa?['nombre']} en CargaExpress. En la app: Perfil > Unirme a una empresa, y usa este código: $_codigo';
    return launchUrl(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(texto)}'), mode: LaunchMode.externalApplication);
  }

  Future<void> _descargar() async {
    final ahora = DateTime.now();
    final mes = '${_resumen?['mes'] ?? '${ahora.year}-${ahora.month.toString().padLeft(2, '0')}'}';
    await _accion(() async {
      final bytes = await EmpresaService.reporte(mes);
      await guardarEnDescargas('CargaExpress_reporte_empresa_$mes.pdf', bytes);
    }, ok: 'Reporte guardado en Descargas');
  }

  Widget _titulo(String t) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(t, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ColoresApp.textoOscuro)),
      );

  static const _gris = TextStyle(fontSize: 13, color: ColoresApp.textoSecundario);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColoresApp.fondo,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: ColoresApp.textoOscuro,
        scrolledUnderElevation: 0,
        shape: const Border(bottom: BorderSide(color: ColoresApp.borde)),
        title: const Text('Mi empresa', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      body: _data == null
          ? (_error != null
              ? ErrorCarga(titulo: 'No pudimos cargar tu empresa', detalle: _error, onReintentar: _cargar)
              : const Center(child: CircularProgressIndicator()))
          : RefreshIndicator(onRefresh: _cargar, child: ListView(padding: const EdgeInsets.all(16), children: _contenido())),
    );
  }

  List<Widget> _contenido() {
    final e = _empresa;
    if (e == null) return const [CajaAviso(texto: 'Tu cuenta no tiene una empresa.')];
    final estado = '${e['estado']}';
    final dueno = e['esDueno'] == true;
    return [
      TarjetaBlanca(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('${e['nombre']}', key: const Key('empresa_nombre'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
            switch (estado) {
              'aprobado' => const ChipEstado.verde('Empresa verificada', icono: Icons.verified),
              'rechazado' => const ChipEstado.rojo('Rechazada'),
              _ => const ChipEstado.naranja('En revisión'),
            },
          ]),
          if (dueno && e['nit'] != null) ...[const SizedBox(height: 8), Text('NIT ${e['nit']}', style: _gris)],
          if (dueno && e['direccion'] != null) Text('${e['direccion']}', style: _gris),
        ]),
      ),
      if (estado == 'pendiente') ...[
        const SizedBox(height: 12),
        const CajaAviso(texto: 'Estamos revisando tus documentos. Te avisaremos cuando tu empresa esté aprobada.'),
      ],
      if (estado == 'rechazado') ...[
        const SizedBox(height: 12),
        CajaAviso(
          texto: 'No pudimos aprobar tu empresa${(e['notaRechazo'] ?? '').toString().isEmpty ? '.' : ': ${e['notaRechazo']}'}',
          icono: Icons.error_outline,
          color: ColoresApp.rojo,
          fondo: ColoresApp.rojoFondo,
        ),
        if (dueno) ...[
          const SizedBox(height: 12),
          BotonPrincipal(texto: 'Corregir y reenviar', icono: Icons.edit_outlined, onPressed: _corregir),
        ],
      ],
      if (estado == 'aprobado' && dueno) ..._dueno(),
      if (estado == 'aprobado' && !dueno) ...[
        const SizedBox(height: 12),
        const CajaAviso(texto: 'Tus envíos quedan a nombre de la empresa y salen en su reporte mensual.', icono: Icons.business_outlined, color: ColoresApp.azul, fondo: ColoresApp.azulTenue),
        const SizedBox(height: 16),
        BotonSecundario(texto: 'Salir de la empresa', icono: Icons.logout, color: ColoresApp.rojo, onPressed: _ocupado ? null : _salir),
      ],
    ];
  }

  List<Widget> _dueno() {
    final r = _resumen;
    final porUsuario = (r?['porUsuario'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? const [];
    final conductores = (r?['conductores'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? const [];
    return [
      _titulo('Código de la empresa'),
      TarjetaBlanca(
        child: Column(children: [
          const Text('Tus empleados lo escriben en Perfil > Unirme a una empresa', style: _gris, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(_codigo, key: const Key('empresa_codigo'), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: 3, color: ColoresApp.azul)),
          const SizedBox(height: 14),
          BotonPrincipal(texto: 'Compartir por WhatsApp', icono: Icons.share_outlined, onPressed: _compartir),
          const SizedBox(height: 8),
          BotonSecundario(texto: 'Copiar', icono: Icons.copy_outlined, onPressed: _copiar),
        ]),
      ),
      _titulo('Equipo'),
      for (final m in _miembros)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: TarjetaBlanca(
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${m['nombre'] ?? ''} ${m['apellido'] ?? ''}'.trim(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  if (m['telefono'] != null) Text('${m['telefono']}', style: const TextStyle(fontSize: 12, color: ColoresApp.textoSecundario)),
                ]),
              ),
              if (m['esDueno'] == true)
                const ChipEstado.azul('Dueño')
              else
                TextButton(
                  onPressed: _ocupado ? null : () => _quitar(m),
                  style: TextButton.styleFrom(foregroundColor: ColoresApp.rojo),
                  child: const Text('Quitar'),
                ),
            ]),
          ),
        ),
      _titulo('Resumen del mes'),
      if (r == null)
        const Text('Todavía no hay envíos este mes.', style: _gris)
      else ...[
        TarjetaBlanca(
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${r['viajes'] ?? 0}', key: const Key('empresa_viajes'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const Text('viajes', style: _gris),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(formatearPesosDe(r['total']), key: const Key('empresa_total'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const Text('total', style: _gris),
            ]),
          ]),
        ),
        if (porUsuario.isNotEmpty) ...[
          const SizedBox(height: 10),
          TarjetaBlanca(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Por persona', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              for (final u in porUsuario)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    Expanded(child: Text('${u['nombre']} · ${u['viajes']} viajes', style: const TextStyle(fontSize: 13))),
                    Text(formatearPesosDe(u['total']), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ]),
                ),
            ]),
          ),
        ],
        if (conductores.isNotEmpty) ...[
          const SizedBox(height: 10),
          TarjetaBlanca(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Conductores más usados', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              for (final c in conductores)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    Expanded(child: Text('${c['nombre']} · ${c['viajes']} viajes', style: const TextStyle(fontSize: 13))),
                    if (c['calificacion'] != null) Text('★ ${c['calificacion']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ]),
                ),
            ]),
          ),
        ],
      ],
      const SizedBox(height: 16),
      BotonPrincipal(texto: 'Descargar reporte', icono: Icons.picture_as_pdf_outlined, cargando: _ocupado, onPressed: _descargar),
    ];
  }
}
