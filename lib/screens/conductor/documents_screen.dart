import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_client.dart';
import '../../services/api/http_client.dart' show ApiException;
import '../../widgets/media_image.dart';
import '../../widgets/error_carga.dart';
import '../../services/socket_service_client.dart';
import '../shared/ui_compartida.dart' show BotonPrincipal, CajaAviso, CajaIcono, ChipEstado, ColoresApp, TarjetaBlanca;

/// Foto guardada de un documento del conductor (clave de `conductor` del perfil).
String? fotoDocumento(Map<String, dynamic>? conductor, String tipo) {
  const campos = {
    'cedula': 'fotoCedula',
    'cedula_reverso': 'fotoCedulaReverso',
    'licencia': 'fotoLicencia',
    'foto_vehiculo': 'fotoVehiculo',
    'foto_conductor': 'fotoConductor',
    'tarjeta_propiedad': 'fotoTarjetaPropiedad',
    'tecnomecanica': 'fotoTecnomecanica',
    'soat': 'fotoSoat',
  };
  final v = conductor?[campos[tipo]];
  return v == null || v.toString().isEmpty ? null : v.toString();
}

/// Estado de un documento, derivado del perfil (el servidor solo guarda un
/// `estadoVerificacion` global): sin foto → `pendiente`; con foto → `aprobado`
/// / `rechazado` según el global, si no `en_validacion`. El SOAT con
/// excepción pedida cuenta como en validación (aprobada → aprobado).
String estadoDocumento(Map<String, dynamic>? conductor, String tipo) {
  if (fotoDocumento(conductor, tipo) == null) {
    if (tipo == 'soat') {
      final exc = conductor?['excepcionSoatEstado'];
      if (exc == 'aprobada') return 'aprobado';
      if (exc == 'pendiente') return 'en_validacion';
    }
    return 'pendiente';
  }
  final global = conductor?['estadoVerificacion'];
  return global == 'aprobado' || global == 'rechazado' ? global as String : 'en_validacion';
}

/// Chip del estado que devuelve [estadoDocumento].
Widget chipDocumento(String estado) => switch (estado) {
      'aprobado' => const ChipEstado.verde('Aprobado', icono: Icons.check_circle),
      'rechazado' => const ChipEstado.rojo('Rechazado', icono: Icons.cancel),
      'en_validacion' => const ChipEstado.naranja('En validación', icono: Icons.schedule),
      _ => const ChipEstado(texto: 'Pendiente', color: ColoresApp.textoSecundario, fondo: ColoresApp.fondoItem, icono: Icons.upload_outlined),
    };

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  Map<String, dynamic>? _conductor;
  bool _loading = true;
  bool _error = false;
  String? _uploadingDoc;
  StreamSubscription<Map<String, dynamic>>? _verificationSub;

  final List<_DocItem> _docs = [
    _DocItem('cedula', 'Cédula (frente)', Icons.badge_outlined),
    _DocItem('cedula_reverso', 'Cédula (reverso)', Icons.badge_outlined),
    _DocItem('licencia', 'Licencia de conducción', Icons.credit_card_outlined),
    _DocItem('foto_vehiculo', 'Foto del vehículo', Icons.directions_car_outlined),
    _DocItem('tarjeta_propiedad', 'Tarjeta de propiedad', Icons.description_outlined),
    _DocItem('tecnomecanica', 'Revisión técnico-mecánica', Icons.build_outlined, conVencimiento: true),
    _DocItem('soat', 'SOAT', Icons.health_and_safety_outlined, conVencimiento: true),
    _DocItem('foto_conductor', 'Foto del conductor', Icons.person_outline),
  ];

  @override
  void initState() {
    super.initState();
    _loadStatus();
    // Actualiza el estado de verificación en tiempo real cuando el admin
    // aprueba o rechaza (driver:approved / driver:rejected).
    _verificationSub = SocketServiceClient.instance.onDriverVerification.listen((data) {
      if (!mounted) return;
      _loadStatus();
      final event = data['__event'] as String?;
      final estado = data['estado'] as String?;
      final nota = data['nota'] as String?;
      final msg = event == 'driver:approved'
          ? (estado == 'aprobado' ? '\u2713 \u00a1Verificaci\u00f3n aprobada! Ya puedes recibir viajes.' : 'Verificaci\u00f3n actualizada: $estado')
          : event == 'driver:rejected'
              ? '\u2717 Verificaci\u00f3n rechazada${nota != null && nota.isNotEmpty ? ': $nota' : ''}. Corrige tus documentos.'
              : event == 'driver:soat_exception'
                  ? (estado == 'aprobada'
                      ? '\u2713 Excepci\u00f3n del SOAT aprobada.'
                      : 'Excepci\u00f3n del SOAT rechazada${nota != null && nota.isNotEmpty ? ': $nota' : ''}.')
                  : null;
      if (msg != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    });
  }

  @override
  void dispose() {
    _verificationSub?.cancel();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    try {
      final data = await ApiClient.instance.getProfile();
      if (mounted) {
        setState(() {
          _conductor = data['conductor'] as Map<String, dynamic>?;
          _loading = false;
          _error = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = _conductor == null; });
    }
  }

  String? _fotoUrl(String docType) => fotoDocumento(_conductor, docType);

  /// Fecha de vencimiento (YYYY-MM-DD) de la tecnomecánica o el SOAT.
  String? _vence(String docType) {
    final v = _conductor?[docType == 'soat' ? 'soatVence' : 'tecnomecanicaVence'];
    return v?.toString().substring(0, 10);
  }

  static bool _vencida(String fecha) => fecha.compareTo(DateTime.now().toIso8601String().substring(0, 10)) < 0;

  static String _fechaLegible(String iso) => '${iso.substring(8, 10)}/${iso.substring(5, 7)}/${iso.substring(0, 4)}';

  String? get _excepcionSoat => _conductor?['excepcionSoatEstado'] as String?;

  String _estado(String docType) => estadoDocumento(_conductor, docType);

  Future<void> _confirmAndUpload(String docType) async {
    final picker = ImagePicker();

    while (true) {
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 75,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      // image_picker la recomprime a JPEG → extensión .jpg.
      final filename = '${docType}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirmar documento'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('¿Es correcto este documento?', style: TextStyle(fontSize: 13)),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(bytes, height: 200, width: double.infinity, fit: BoxFit.cover, cacheHeight: 600),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No, volver a tomar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(foregroundColor: Colors.white, backgroundColor: ColoresApp.azulOscuro),
              child: const Text('Sí, subir', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        if (!mounted) return;
        String? vence;
        if (_docs.firstWhere((d) => d.type == docType).conVencimiento) {
          final hoy = DateTime.now();
          final fecha = await showDatePicker(
            context: context,
            initialDate: hoy,
            firstDate: hoy,
            lastDate: DateTime(hoy.year + 10),
            helpText: 'Fecha de vencimiento',
          );
          if (fecha == null || !mounted) return;
          vence = fecha.toIso8601String().substring(0, 10);
        }
        final messenger = ScaffoldMessenger.of(context);
        setState(() => _uploadingDoc = docType);
        try {
          switch (docType) {
            case 'cedula':
              await ApiClient.instance.uploadDocumentCedula(bytes, filename);
              break;
            case 'licencia':
              await ApiClient.instance.uploadDocumentLicencia(bytes, filename);
              break;
            case 'foto_vehiculo':
              await ApiClient.instance.uploadDocumentVehiculo(bytes, filename);
              break;
            case 'foto_conductor':
              await ApiClient.instance.uploadDocumentDriverPhoto(bytes, filename);
              break;
            default:
              // cedula_reverso, tarjeta_propiedad, tecnomecanica, soat
              await ApiClient.instance.uploadDocumento(docType.replaceAll('_', '-'), bytes, filename, vence: vence);
          }
          await _loadStatus();
          messenger.showSnackBar(
            const SnackBar(content: Text('Documento subido correctamente')),
          );
        } on ApiException catch (e) {
          messenger.showSnackBar(SnackBar(content: Text(e.message)));
        } catch (e) {
          messenger.showSnackBar(
            SnackBar(content: Text('Error: ${e.toString().replaceFirst("Exception: ", "")}')),
          );
        } finally {
          if (mounted) setState(() => _uploadingDoc = null);
        }
        return;
      }
    }
  }

  void _showDocumentPreview(String docType) {
    final url = _fotoUrl(docType);
    if (url == null || url.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _docs.firstWhere((d) => d.type == docType).title,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                // URL firmada (caduca en 1 h): se resuelve con resolveMediaUrl y
                // _loadStatus() la renueva al volver a cargar el perfil.
                child: MediaImage(
                  path: url,
                  height: 300,
                  width: double.infinity,
                  placeholder: Container(
                    height: 300,
                    color: ColoresApp.fondo,
                    child: const Center(child: Text('Imagen no disponible', style: TextStyle(color: Colors.black45))),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cerrar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _solicitarExcepcionSoat() async {
    final enviada = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const _SolicitudSoatScreen()));
    if (enviada == true && mounted) _loadStatus();
  }

  /// Debajo de la tarjeta del SOAT: estado de la excepción o el enlace para pedirla.
  Widget _buildExcepcionSoat() {
    final estado = _excepcionSoat;
    final nota = _conductor?['excepcionSoatNota'] as String?;
    if (estado == 'pendiente' || estado == 'aprobada') {
      final ok = estado == 'aprobada';
      final color = ok ? ColoresApp.verde : ColoresApp.naranja;
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Icon(ok ? Icons.verified_outlined : Icons.schedule, size: 16, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                ok ? 'Excepción del SOAT aprobada' : 'El equipo de Carga Express está revisando tu solicitud.',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
              ),
            ),
          ],
        ),
      );
    }
    if (_fotoUrl('soat') != null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (estado == 'rechazada')
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                'Excepción del SOAT rechazada${nota != null && nota.isNotEmpty ? ': $nota' : ''}',
                style: TextStyle(fontSize: 12, color: ColoresApp.rojo),
              ),
            ),
          Row(
            children: [
              const Text('¿No tienes SOAT?', style: TextStyle(fontSize: 12, color: ColoresApp.textoSecundario)),
              TextButton(
                key: const Key('soat_excepcion'),
                onPressed: _solicitarExcepcionSoat,
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6), foregroundColor: ColoresApp.azul),
                child: const Text('Enviar solicitud', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, decoration: TextDecoration.underline)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showRejectionNote() {
    final nota = _conductor?['notaRechazo'] as String?;
    if (nota == null || nota.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Motivo del rechazo'),
        content: Text(nota),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColoresApp.fondo,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: ColoresApp.textoOscuro),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Documentos', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: ColoresApp.textoOscuro)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error
          ? ErrorCarga(
              titulo: 'No se pudieron cargar tus documentos',
              onReintentar: () {
                setState(() { _loading = true; _error = false; });
                _loadStatus();
              },
            )
          : Column(
              children: [
                _buildStatusBanner(),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      for (final doc in _docs) ...[
                        _buildDocCard(doc),
                        if (doc.type == 'soat') _buildExcepcionSoat(),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatusBanner() {
    final estado = _conductor?['estadoVerificacion'] as String? ?? 'pendiente';
    if (estado == 'aprobado') {
      return Container(
        width: double.infinity,
        color: ColoresApp.verde.withValues(alpha: 0.12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.verified, color: ColoresApp.verde, size: 20),
            const SizedBox(width: 8),
            const Expanded(child: Text('Documentos aprobados', style: TextStyle(fontWeight: FontWeight.w600, color: ColoresApp.verdeOscuro))),
          ],
        ),
      );
    }
    if (estado == 'rechazado') {
      return GestureDetector(
        onTap: _showRejectionNote,
        child: Container(
          width: double.infinity,
          color: ColoresApp.rojo.withValues(alpha: 0.08),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.cancel, color: ColoresApp.rojo, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Documentos rechazados. Toca para ver motivo.',
                  style: TextStyle(fontWeight: FontWeight.w600, color: ColoresApp.rojo),
                ),
              ),
              Icon(Icons.chevron_right, color: ColoresApp.rojo, size: 20),
            ],
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildDocCard(_DocItem doc) {
    final estado = _estado(doc.type);
    final subiendo = _uploadingDoc == doc.type;
    final nota = _conductor?['notaRechazo'] as String?;
    final foto = _fotoUrl(doc.type);
    final vence = doc.conVencimiento && foto != null ? _vence(doc.type) : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TarjetaBlanca(
        radio: 14,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: ColoresApp.azulOscuro.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(doc.icon, color: ColoresApp.azulOscuro, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(doc.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  if (vence != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        _vencida(vence) ? 'Vencido el ${_fechaLegible(vence)}' : 'Vence el ${_fechaLegible(vence)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _vencida(vence) ? ColoresApp.rojo : ColoresApp.verde,
                        ),
                      ),
                    ),
                  if (estado == 'rechazado' && nota != null && nota.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(nota, style: TextStyle(fontSize: 12, color: ColoresApp.rojo.withValues(alpha: 0.7)), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                  if (foto != null) ...[
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () => _showDocumentPreview(doc.type),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: MediaImage(
                          path: foto,
                          height: 56,
                          width: 80,
                          placeholder: Container(
                            height: 56,
                            width: 80,
                            color: ColoresApp.fondo,
                            child: const Center(child: Icon(Icons.image, size: 24, color: Colors.black26)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            subiendo
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5))
                : _buildAction(doc.type, estado),
          ],
        ),
      ),
    );
  }

  Widget _buildAction(String docType, String estado) {
    // Botón chico (36 px) para subir o volver a subir; los chips son de ChipEstado.
    Widget subir(String texto, Color color) => SizedBox(
          width: 92,
          height: 36,
          child: FilledButton(
            onPressed: () => _confirmAndUpload(docType),
            style: FilledButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            child: Text(texto),
          ),
        );
    final chip = chipDocumento(estado);
    final sinFoto = _fotoUrl(docType) == null;
    final Widget? boton = switch (estado) {
      'rechazado' => subir('Re-subir', ColoresApp.rojo),
      // Aprobado sin foto = excepción del SOAT aprobada: no hay nada que subir.
      'aprobado' => null,
      _ => sinFoto ? subir('Subir', ColoresApp.azul) : null,
    };
    if (boton == null) return chip;
    return Column(mainAxisSize: MainAxisSize.min, children: [chip, const SizedBox(height: 6), boton]);
  }
}

/// "Solicitud de validación" del SOAT: asunto y tipo fijos, información
/// adicional opcional. Usa el mismo endpoint de la excepción del SOAT.
class _SolicitudSoatScreen extends StatefulWidget {
  const _SolicitudSoatScreen();

  @override
  State<_SolicitudSoatScreen> createState() => _SolicitudSoatScreenState();
}

class _SolicitudSoatScreenState extends State<_SolicitudSoatScreen> {
  final _info = TextEditingController();
  bool _enviando = false;
  bool _enviada = false;
  String? _error;

  @override
  void dispose() {
    _info.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      await ApiClient.instance.solicitarExcepcionSoat(_info.text.trim());
      if (mounted) setState(() => _enviada = true);
    } catch (e) {
      if (mounted) setState(() => _error = mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Widget _fijo(String label, String valor, IconData icono) => TextFormField(
        initialValue: valor,
        enabled: false,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icono, size: 20)),
      );

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_enviada,
      onPopInvokedWithResult: (hecho, _) {
        if (!hecho) Navigator.pop(context, true);
      },
      child: Scaffold(
        backgroundColor: ColoresApp.fondo,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: _enviada
              ? null
              : IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: ColoresApp.textoOscuro),
                  onPressed: () => Navigator.pop(context),
                ),
          automaticallyImplyLeading: false,
          title: Text(
            _enviada ? 'Solicitud enviada' : 'Solicitud de validación',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: ColoresApp.textoOscuro),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: _enviada
              ? TarjetaBlanca(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: CajaIcono(icono: Icons.check_circle_rounded, color: ColoresApp.verde, tamano: 64)),
                      const SizedBox(height: 16),
                      const Text('Solicitud enviada', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: ColoresApp.textoOscuro)),
                      const SizedBox(height: 6),
                      const Text('Tu solicitud fue recibida correctamente.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: ColoresApp.textoSecundario)),
                      const SizedBox(height: 16),
                      const Center(child: ChipEstado.naranja('En validación', icono: Icons.schedule)),
                      const SizedBox(height: 8),
                      const Text('El equipo de Carga Express está revisando tu solicitud.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: ColoresApp.textoSecundario)),
                      const SizedBox(height: 20),
                      BotonPrincipal(key: const Key('btn_volver_documentos'), texto: 'Volver a documentos', onPressed: () => Navigator.pop(context, true)),
                    ],
                  ),
                )
              : TarjetaBlanca(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _fijo('Asunto', 'SOAT', Icons.health_and_safety_outlined),
                      const SizedBox(height: 12),
                      _fijo('Tipo', 'Validación de vehículo', Icons.fact_check_outlined),
                      const SizedBox(height: 12),
                      TextField(
                        key: const Key('campo_info_soat'),
                        controller: _info,
                        enabled: !_enviando,
                        maxLines: 4,
                        maxLength: 500,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Información adicional (opcional)',
                          alignLabelWithHint: true,
                          hintText: 'Cuéntanos por qué tu vehículo no tiene SOAT',
                          counterText: '',
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        CajaAviso(texto: _error!, icono: Icons.error_outline, color: ColoresApp.rojo, fondo: ColoresApp.rojoFondo),
                      ],
                      const SizedBox(height: 16),
                      BotonPrincipal(key: const Key('btn_enviar_soat'), texto: 'Enviar solicitud', cargando: _enviando, onPressed: _enviando ? null : _enviar),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _DocItem {
  final String type;
  final String title;
  final IconData icon;
  /// Pide la fecha de vencimiento al subir (tecnomecánica y SOAT).
  final bool conVencimiento;
  const _DocItem(this.type, this.title, this.icon, {this.conVencimiento = false});
}
