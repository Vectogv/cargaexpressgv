import 'package:flutter/material.dart';
import '../../contracts/validacion_usuario.dart';
import '../../services/api_client.dart';
import '../../services/api/http_client.dart' show ApiException;
import '../user/auth_estilos.dart';
import 'ui_compartida.dart' show DialogoApp;

/// "Acerca de nosotros", compartido por Ajustes del cliente y los dos perfiles.
void mostrarAcercaDe(BuildContext context) {
  showAboutDialog(
    context: context,
    applicationName: 'CargaExpress',
    applicationVersion: '1.0.0',
    children: const [Text('Envíos de carga con conductores verificados.')],
  );
}

/// Diálogo rápido del contacto de emergencia (mismo PUT /api/users/profile que
/// "Editar perfil"). [perfil] trae los valores actuales; [obligatorio] exige
/// nombre y teléfono (conductor). Devuelve true si se guardó.
Future<bool> mostrarDialogoEmergencia(BuildContext context, Map<String, dynamic>? perfil, {required bool obligatorio}) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DialogoEmergencia(perfil: perfil, obligatorio: obligatorio),
  );
  if (ok == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contacto de emergencia actualizado')));
  }
  return ok == true;
}

class _DialogoEmergencia extends StatefulWidget {
  final Map<String, dynamic>? perfil;
  final bool obligatorio;
  const _DialogoEmergencia({required this.perfil, required this.obligatorio});

  @override
  State<_DialogoEmergencia> createState() => _DialogoEmergenciaState();
}

class _DialogoEmergenciaState extends State<_DialogoEmergencia> {
  late final _nombre = TextEditingController(text: widget.perfil?['contactoEmergenciaNombre'] as String? ?? '');
  late final _telefono = TextEditingController(text: widget.perfil?['contactoEmergenciaTelefono'] as String? ?? '');
  String? _error;
  bool _guardando = false;

  @override
  void dispose() {
    _nombre.dispose();
    _telefono.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final nombre = _nombre.text.trim();
    final telefono = _telefono.text.trim();
    if (widget.obligatorio && nombre.isEmpty) {
      setState(() => _error = 'El nombre del contacto es obligatorio');
      return;
    }
    final errTel = validarTelefono(telefono, opcional: !widget.obligatorio);
    if (errTel != null) {
      setState(() => _error = errTel);
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await ApiClient.instance.updateProfile(cuerpoActualizacionPerfil(
        nombre: '',
        apellido: '',
        telefono: '',
        contactoNombre: nombre,
        contactoTelefono: telefono,
      ));
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      setState(() {
        _guardando = false;
        _error = e.message;
      });
    } catch (e) {
      setState(() {
        _guardando = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_guardando,
      child: DialogoApp(
        desplazable: true,
        icono: Icons.emergency_outlined,
        titulo: 'Número de emergencia',
        cuerpo: widget.obligatorio
            ? 'Lo llamamos si activas el SOS durante un viaje. Es obligatorio.'
            : 'Opcional. Lo llamamos solo si activas el SOS.',
        contenido: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const Key('campo_emergencia_nombre'),
              controller: _nombre,
              enabled: !_guardando,
              textCapitalization: TextCapitalization.words,
              decoration: decoracionCampoAuth(label: 'Nombre del contacto', icono: Icons.person_outline),
            ),
            const SizedBox(height: 14),
            TextField(
              key: const Key('campo_emergencia_telefono'),
              controller: _telefono,
              enabled: !_guardando,
              keyboardType: TextInputType.phone,
              decoration: decoracionCampoAuth(label: 'Teléfono del contacto', icono: Icons.phone_outlined),
            ),
            if (_error != null) ...[const SizedBox(height: 8), AvisoErrorAuth(mensaje: _error!)],
          ],
        ),
        textoPrincipal: 'Guardar',
        cargando: _guardando,
        onPrincipal: _guardar,
        textoSecundario: 'Cancelar',
        onSecundario: () => Navigator.pop(context, false),
      ),
    );
  }
}
