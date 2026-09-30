import 'package:flutter/material.dart';
import '../../services/api/http_client.dart';
import '../shared/tickets/tickets_ui.dart' show tiempoRelativoTicket;
import '../shared/ui_compartida.dart';
import '../user/auth_estilos.dart' show decoracionCampoAuth;

/// Grupo de Conductores de la zona (GET /api/drivers/grupo): comunicados de
/// Gerencia, anuncios y quién es el líder. El líder, además, publica anuncios
/// (/api/leader/avisos) y envía inquietudes a Gerencia
/// (/api/leader/comunicados). El líder no sanciona ni reemplaza al moderador.
/// Todos comentan los anuncios; borra el autor del comentario o el líder.
class GrupoConductoresScreen extends StatefulWidget {
  const GrupoConductoresScreen({super.key});

  @override
  State<GrupoConductoresScreen> createState() => _GrupoConductoresScreenState();
}

class _GrupoConductoresScreenState extends State<GrupoConductoresScreen> {
  Map<String, dynamic>? _grupo;
  String? _error;
  bool _cargando = true;
  final Set<Object?> _expandidos = {};

  bool get _esLider => _grupo?['esLider'] == true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final g = await HttpClient.get('/api/drivers/grupo', auth: true);
      if (mounted) setState(() => _grupo = g);
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : 'No pudimos cargar el grupo');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  List<Map<String, dynamic>> _lista(String clave) =>
      (_grupo?[clave] as List?)?.whereType<Map<String, dynamic>>().toList() ?? const [];

  Future<void> _accion(Future<void> Function() f, String exito) async {
    try {
      await f();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(exito)));
      _cargar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : 'No se pudo completar')));
    }
  }

  /// Formulario de texto (anuncio o inquietud). Devuelve {titulo?, contenido}.
  Future<Map<String, String>?> _formulario({required String titulo, required String boton, bool conTitulo = false, int maxLength = 1000}) {
    final t = TextEditingController();
    final c = TextEditingController();
    return showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(titulo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            if (conTitulo) ...[
              TextField(key: const Key('grupo_campo_titulo'), controller: t, maxLength: 120, decoration: decoracionCampoAuth(label: 'Asunto', icono: Icons.subject)),
              const SizedBox(height: 8),
            ],
            TextField(
              key: const Key('grupo_campo_contenido'),
              controller: c,
              minLines: 3,
              maxLines: 6,
              maxLength: maxLength,
              decoration: decoracionCampoAuth(label: 'Mensaje', icono: Icons.chat_bubble_outline),
            ),
            const SizedBox(height: 8),
            BotonPrincipal(
              texto: boton,
              onPressed: () {
                if (c.text.trim().isEmpty || (conTitulo && t.text.trim().isEmpty)) return;
                Navigator.pop(ctx, {if (conTitulo) 'titulo': t.text.trim(), 'contenido': c.text.trim()});
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _publicarAnuncio() async {
    final r = await _formulario(titulo: 'Nuevo anuncio para el grupo', boton: 'Publicar');
    if (r == null) return;
    await _accion(() => HttpClient.post('/api/leader/avisos', body: r, auth: true), 'Anuncio publicado');
  }

  Future<void> _enviarInquietud() async {
    final r = await _formulario(titulo: 'Inquietud para Gerencia', boton: 'Enviar a Gerencia', conTitulo: true);
    if (r == null) return;
    await _accion(() => HttpClient.post('/api/leader/comunicados', body: r, auth: true), 'Enviado a Gerencia. Te avisaremos cuando lo revisen.');
  }

  Future<void> _verInquietudes() async {
    try {
      final lista = await HttpClient.getList('/api/leader/comunicados', auth: true);
      if (!mounted) return;
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        backgroundColor: Colors.white,
        builder: (_) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            const Text('Mis inquietudes a Gerencia', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            if (lista.isEmpty) const Text('Aún no has enviado inquietudes.', style: TextStyle(color: ColoresApp.textoSecundario)),
            for (final i in lista.whereType<Map<String, dynamic>>())
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${i['titulo'] ?? ''}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                subtitle: Text('${i['contenido'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing: _Etiqueta(texto: _estadoInquietud('${i['estado']}'), color: i['estado'] == 'rechazado' ? ColoresApp.rojo : i['estado'] == 'aprobado' ? ColoresApp.verde : ColoresApp.naranja),
              ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : 'No se pudo cargar')));
    }
  }

  static String _estadoInquietud(String e) => switch (e) {
        'aprobado' => 'Revisada',
        'rechazado' => 'Rechazada',
        _ => 'Pendiente',
      };

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
        title: const Text('Grupo de conductores', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      floatingActionButton: _esLider
          ? FloatingActionButton.extended(
              key: const Key('grupo_btn_publicar'),
              onPressed: _publicarAnuncio,
              backgroundColor: ColoresApp.azul,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.campaign_outlined),
              label: const Text('Publicar anuncio'),
            )
          : null,
      body: _cargando && _grupo == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _grupo == null
              ? _errorVista()
              : RefreshIndicator(onRefresh: _cargar, child: _contenido()),
    );
  }

  Widget _errorVista() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.groups_outlined, size: 48, color: ColoresApp.chevron),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            BotonSecundario(texto: 'Reintentar', onPressed: _cargar),
          ]),
        ),
      );

  Widget _contenido() {
    final lider = _grupo?['lider'] as Map<String, dynamic>?;
    final comunicados = _lista('comunicados');
    final avisos = _lista('avisos')..sort((a, b) => (b['fijado'] == true ? 1 : 0) - (a['fijado'] == true ? 1 : 0));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        _encabezado(lider),
        if (_esLider) ...[const SizedBox(height: 12), _panelLider()],
        const SizedBox(height: 20),
        _titulo('Comunicados de Gerencia', Icons.apartment_outlined),
        if (comunicados.isEmpty) _vacio('No hay comunicados de Gerencia.'),
        for (final c in comunicados) _tarjetaComunicado(c),
        const SizedBox(height: 20),
        _titulo('Anuncios del grupo', Icons.campaign_outlined),
        if (avisos.isEmpty) _vacio(_esLider ? 'Publica el primer anuncio para tu grupo.' : 'Aún no hay anuncios. El líder del grupo los publica aquí.'),
        for (final a in avisos) _tarjetaAviso(a),
      ],
    );
  }

  Widget _encabezado(Map<String, dynamic>? lider) {
    final zona = '${_grupo?['zona'] ?? 'Tu zona'}';
    return TarjetaBlanca(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.groups_rounded, color: ColoresApp.azul),
            const SizedBox(width: 8),
            Expanded(child: Text('Conductores de $zona', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: ColoresApp.textoOscuro))),
            _Etiqueta(key: const Key('grupo_rol'), texto: _esLider ? 'Líder' : 'Conductor', color: _esLider ? ColoresApp.ambar : ColoresApp.azul),
          ]),
          const Divider(height: 24, color: ColoresApp.divisor),
          const Text('Líder del grupo', style: TextStyle(fontSize: 12, color: ColoresApp.textoSecundario)),
          const SizedBox(height: 6),
          if (lider == null)
            const Text('Tu zona aún no tiene líder.', style: TextStyle(color: ColoresApp.textoSecundario))
          else
            Row(children: [
              CircleAvatar(radius: 18, backgroundColor: ColoresApp.naranjaFondo, child: const Icon(Icons.star_rounded, color: ColoresApp.ambar)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(_esLider ? '${lider['nombre'] ?? ''} (tú)' : '${lider['nombre'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: ColoresApp.textoOscuro)),
              ),
            ]),
          const SizedBox(height: 10),
          const Text(
            'El líder es un conductor vocero: comparte anuncios y lleva las inquietudes del grupo a Gerencia. No sanciona ni reemplaza al moderador.',
            style: TextStyle(fontSize: 12, color: ColoresApp.textoSecundario, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _panelLider() => TarjetaBlanca(
        key: const Key('grupo_panel_lider'),
        colorBorde: ColoresApp.naranjaBorde,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Herramientas de líder', style: TextStyle(fontWeight: FontWeight.w800, color: ColoresApp.naranjaAviso)),
            const SizedBox(height: 10),
            BotonSecundario(texto: 'Escribir a Gerencia', icono: Icons.send_outlined, onPressed: _enviarInquietud),
            const SizedBox(height: 8),
            BotonSecundario(texto: 'Mis inquietudes enviadas', icono: Icons.history_rounded, onPressed: _verInquietudes),
          ],
        ),
      );

  Widget _titulo(String texto, IconData icono) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Icon(icono, size: 18, color: ColoresApp.textoSecundario),
          const SizedBox(width: 6),
          Text(texto, style: const TextStyle(fontWeight: FontWeight.w800, color: ColoresApp.textoOscuro)),
        ]),
      );

  Widget _vacio(String texto) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(texto, style: const TextStyle(color: ColoresApp.textoSecundario)),
      );

  Widget _tarjetaComunicado(Map<String, dynamic> c) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TarjetaBlanca(
          colorBorde: ColoresApp.azulTenue,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${c['titulo'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700, color: ColoresApp.azulOscuro)),
            const SizedBox(height: 4),
            Text('${c['contenido'] ?? ''}', style: const TextStyle(height: 1.35)),
            const SizedBox(height: 6),
            Text(tiempoRelativoTicket(DateTime.tryParse('${c['createdAt']}')?.toLocal()), style: const TextStyle(fontSize: 11, color: ColoresApp.textoSecundario)),
          ]),
        ),
      );

  Widget _tarjetaAviso(Map<String, dynamic> a) {
    final autor = a['autor'] as Map<String, dynamic>?;
    final fijado = a['fijado'] == true;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TarjetaBlanca(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (fijado) const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.push_pin, size: 16, color: ColoresApp.ambar)),
            Expanded(
              child: Text('${autor?['nombre'] ?? 'Grupo'} ${autor?['apellido'] ?? ''}'.trim(),
                  style: const TextStyle(fontWeight: FontWeight.w700, color: ColoresApp.textoOscuro)),
            ),
            Text(tiempoRelativoTicket(DateTime.tryParse('${a['createdAt']}')?.toLocal()), style: const TextStyle(fontSize: 11, color: ColoresApp.textoSecundario)),
            if (_esLider)
              PopupMenuButton<String>(
                key: Key('grupo_menu_aviso_${a['id']}'),
                color: Colors.white,
                onSelected: (op) => op == 'fijar'
                    ? _accion(() => HttpClient.put('/api/leader/avisos/${a['id']}/pin', auth: true), fijado ? 'Anuncio desfijado' : 'Anuncio fijado')
                    : _accion(() => HttpClient.delete('/api/leader/avisos/${a['id']}', auth: true), 'Anuncio eliminado'),
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'fijar', child: Text(fijado ? 'Desfijar' : 'Fijar arriba')),
                  const PopupMenuItem(value: 'eliminar', child: Text('Eliminar')),
                ],
              ),
          ]),
          const SizedBox(height: 6),
          Text('${a['contenido'] ?? ''}', style: const TextStyle(height: 1.35)),
          _comentarios(a),
        ]),
      ),
    );
  }

  Future<void> _comentar(Map<String, dynamic> a) async {
    final r = await _formulario(titulo: 'Comentar el anuncio', boton: 'Comentar', maxLength: 500);
    if (r == null) return;
    await _accion(
      () => HttpClient.post('/api/drivers/grupo/avisos/${a['id']}/comentarios', body: {'contenido': r['contenido']}, auth: true),
      'Comentario publicado',
    );
  }

  /// Comentarios del anuncio: los últimos 3 (o todos si se expande) y "Comentar".
  Widget _comentarios(Map<String, dynamic> a) {
    final lista = (a['comentarios'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? const [];
    final todos = _expandidos.contains(a['id']);
    final visibles = todos || lista.length <= 3 ? lista : lista.sublist(lista.length - 3);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (lista.isNotEmpty) const Divider(height: 20, color: ColoresApp.divisor),
      if (visibles.length < lista.length)
        GestureDetector(
          onTap: () => setState(() => _expandidos.add(a['id'])),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('Ver los ${lista.length} comentarios', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ColoresApp.azul)),
          ),
        ),
      for (final c in visibles) _comentario(c),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          key: Key('grupo_comentar_${a['id']}'),
          onPressed: () => _comentar(a),
          style: TextButton.styleFrom(padding: EdgeInsets.zero, foregroundColor: ColoresApp.azul),
          icon: const Icon(Icons.mode_comment_outlined, size: 18),
          label: const Text('Comentar'),
        ),
      ),
    ]);
  }

  Widget _comentario(Map<String, dynamic> c) {
    final autor = c['autor'] as Map<String, dynamic>?;
    final nombre = c['propio'] == true ? 'Tú' : '${autor?['nombre'] ?? ''} ${autor?['apellido'] ?? ''}'.trim();
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(color: ColoresApp.fondo, borderRadius: BorderRadius.circular(12)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$nombre · ${tiempoRelativoTicket(DateTime.tryParse('${c['createdAt']}')?.toLocal())}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ColoresApp.textoSecundario)),
            const SizedBox(height: 2),
            Text('${c['contenido'] ?? ''}', style: const TextStyle(fontSize: 14, height: 1.3)),
          ]),
        ),
        if (c['puedeBorrar'] == true)
          IconButton(
            key: Key('grupo_borrar_comentario_${c['id']}'),
            tooltip: 'Borrar comentario',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.delete_outline, size: 18, color: ColoresApp.textoSecundario),
            onPressed: () => _accion(() => HttpClient.delete('/api/drivers/grupo/comentarios/${c['id']}', auth: true), 'Comentario borrado'),
          ),
      ]),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  final String texto;
  final Color color;
  const _Etiqueta({super.key, required this.texto, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
        child: Text(texto, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
      );
}
