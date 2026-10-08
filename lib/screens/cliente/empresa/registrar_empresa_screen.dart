import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../contracts/validacion_usuario.dart';
import '../../../services/api/empresa_service.dart';
import '../../../widgets/error_carga.dart' show mensajeDeError;
import '../../shared/ui_compartida.dart';
import '../../user/auth_estilos.dart';

/// NIT solo con dígitos (6 a 15), sin puntos ni guiones.
String? validarNit(String valor) {
  final v = valor.trim();
  if (v.isEmpty) return 'El NIT es obligatorio';
  if (!RegExp(r'^[0-9]{6,15}$').hasMatch(v)) return 'El NIT debe tener entre 6 y 15 dígitos, sin puntos ni guiones';
  return null;
}

/// Registro de la empresa (POST /api/empresas) o corrección de una rechazada
/// ([inicial] trae los datos anteriores). Cierra con `true` si se envió.
class RegistrarEmpresaScreen extends StatefulWidget {
  final Map<String, dynamic>? inicial;

  /// Solo para pruebas: reemplaza el selector de fotos.
  final Future<Uint8List?> Function(ImageSource origen)? elegirFoto;

  const RegistrarEmpresaScreen({super.key, this.inicial, this.elegirFoto});

  @override
  State<RegistrarEmpresaScreen> createState() => _RegistrarEmpresaScreenState();
}

class _RegistrarEmpresaScreenState extends State<RegistrarEmpresaScreen> {
  final _form = GlobalKey<FormState>();
  late final _nombre = TextEditingController(text: '${widget.inicial?['nombre'] ?? ''}');
  late final _nit = TextEditingController(text: '${widget.inicial?['nit'] ?? ''}');
  late final _direccion = TextEditingController(text: '${widget.inicial?['direccion'] ?? ''}');
  late final _telefono = TextEditingController(text: '${widget.inicial?['telefono'] ?? ''}');
  Uint8List? _rut;
  Uint8List? _camara;
  bool _enviando = false;
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    _nit.dispose();
    _direccion.dispose();
    _telefono.dispose();
    super.dispose();
  }

  Future<void> _elegir(bool esRut, ImageSource origen) async {
    try {
      Uint8List? bytes;
      if (widget.elegirFoto != null) {
        bytes = await widget.elegirFoto!(origen);
      } else {
        final p = await ImagePicker().pickImage(source: origen, maxWidth: 1600, maxHeight: 1600, imageQuality: 75);
        bytes = p == null ? null : await p.readAsBytes();
      }
      if (bytes == null || !mounted) return;
      setState(() => esRut ? _rut = bytes : _camara = bytes);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo abrir la ${origen == ImageSource.camera ? 'cámara' : 'galería'}.');
    }
  }

  Future<void> _enviar() async {
    if (_enviando) return;
    if (!_form.currentState!.validate()) return;
    if (_rut == null || _camara == null) {
      setState(() => _error = 'Agrega las fotos del RUT y de la Cámara de Comercio.');
      return;
    }
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      await EmpresaService.registrar(
        nombre: _nombre.text.trim(),
        nit: _nit.text.trim(),
        direccion: _direccion.text.trim(),
        telefono: _telefono.text.trim(),
        rut: _rut!,
        rutNombre: 'rut.jpg',
        camara: _camara!,
        camaraNombre: 'camara.jpg',
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _enviando = false;
          _error = mensajeDeError(e);
        });
      }
    }
  }

  Widget _campo(TextEditingController c, String label, IconData icono,
      {String? Function(String?)? validar, TextInputType? teclado, List<TextInputFormatter>? formato, int? max}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        enabled: !_enviando,
        keyboardType: teclado,
        inputFormatters: formato,
        maxLength: max,
        decoration: decoracionCampoAuth(label: label, icono: icono).copyWith(counterText: ''),
        validator: validar,
      ),
    );
  }

  Widget _documento(String titulo, Uint8List? bytes, bool esRut) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TarjetaBlanca(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(titulo, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
            if (bytes != null) const ChipEstado.verde('Lista', icono: Icons.check_circle_outline),
          ]),
          if (bytes != null) ...[
            const SizedBox(height: 10),
            ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(bytes, height: 110, width: double.infinity, fit: BoxFit.cover)),
          ],
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: BotonSecundario(
                  texto: 'Tomar foto', icono: Icons.photo_camera_outlined, alto: 44, onPressed: _enviando ? null : () => _elegir(esRut, ImageSource.camera)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: BotonSecundario(
                  texto: 'Galería', icono: Icons.photo_library_outlined, alto: 44, onPressed: _enviando ? null : () => _elegir(esRut, ImageSource.gallery)),
            ),
          ]),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final corrige = widget.inicial != null;
    return Scaffold(
      backgroundColor: ColoresApp.fondo,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: ColoresApp.textoOscuro,
        scrolledUnderElevation: 0,
        shape: const Border(bottom: BorderSide(color: ColoresApp.borde)),
        title: Text(corrige ? 'Corregir mi empresa' : 'Registrar mi empresa', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          const Text(
            'Con tu empresa verificada, los conductores ven el sello "Empresa verificada" y tu equipo pide envíos con un mismo reporte mensual. Revisamos los documentos antes de aprobarla.',
            style: TextStyle(fontSize: 13, height: 1.4, color: ColoresApp.textoSecundario),
          ),
          const SizedBox(height: 16),
          _campo(_nombre, 'Nombre de la empresa', Icons.business_outlined,
              max: 100, validar: (v) => (v ?? '').trim().isEmpty ? 'El nombre es obligatorio' : null),
          _campo(_nit, 'NIT (solo números)', Icons.badge_outlined,
              teclado: TextInputType.number, formato: [FilteringTextInputFormatter.digitsOnly], max: 15, validar: (v) => validarNit(v ?? '')),
          _campo(_direccion, 'Dirección', Icons.place_outlined,
              max: 150, validar: (v) => (v ?? '').trim().isEmpty ? 'La dirección es obligatoria' : null),
          _campo(_telefono, 'Teléfono de la empresa', Icons.phone_outlined,
              teclado: TextInputType.phone, max: LimitesUsuario.telefono, validar: (v) => validarTelefono(v ?? '')),
          _documento('RUT', _rut, true),
          _documento('Cámara de Comercio', _camara, false),
          if (_error != null) ...[
            CajaAviso(texto: _error!, icono: Icons.error_outline, color: ColoresApp.rojo, fondo: ColoresApp.rojoFondo),
            const SizedBox(height: 12),
          ],
          BotonPrincipal(texto: corrige ? 'Reenviar para revisión' : 'Enviar para revisión', cargando: _enviando, onPressed: _enviar),
        ]),
      ),
    );
  }
}
