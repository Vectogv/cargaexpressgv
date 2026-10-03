import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../services/api/http_client.dart' show ApiException;
import '../../services/driver_location_service.dart';
import '../user/auth_estilos.dart';
import '../user/auth_screen.dart';
import 'ui_compartida.dart' show ColoresApp, DialogoApp;

/// "Eliminar mi cuenta" (Ajustes del cliente y del conductor): Play exige que
/// el usuario pueda borrar su cuenta desde la app. Pide escribir ELIMINAR para
/// no borrarla por un toque accidental; al terminar vuelve al login.
Future<void> mostrarDialogoEliminarCuenta(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _DialogoEliminarCuenta(),
  );
  if (ok != true || !context.mounted) return;
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const AuthScreen()),
    (_) => false,
  );
  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tu cuenta fue eliminada')));
}

class _DialogoEliminarCuenta extends StatefulWidget {
  const _DialogoEliminarCuenta();

  @override
  State<_DialogoEliminarCuenta> createState() => _DialogoEliminarCuentaState();
}

class _DialogoEliminarCuentaState extends State<_DialogoEliminarCuenta> {
  static const _palabra = 'ELIMINAR';
  final _texto = TextEditingController();
  String? _error;
  bool _borrando = false;

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  Future<void> _eliminar() async {
    if (_texto.text.trim().toUpperCase() != _palabra) {
      setState(() => _error = 'Escribe $_palabra para confirmar');
      return;
    }
    setState(() {
      _borrando = true;
      _error = null;
    });
    try {
      await ApiClient.instance.eliminarCuenta();
      // Después del éxito: con un 409 (viaje activo) el conductor sigue enviando su ubicación.
      DriverLocationService.instance.stop();
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      // 409: viaje activo o deuda pendiente; el servidor explica cuál.
      setState(() {
        _borrando = false;
        _error = e.message;
      });
    } catch (e) {
      setState(() {
        _borrando = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_borrando,
      child: DialogoApp(
        desplazable: true,
        icono: Icons.delete_forever_outlined,
        colorIcono: ColoresApp.rojo,
        titulo: '¿Eliminar tu cuenta?',
        contenido: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Se borran tu perfil, tus fotos, tus documentos y tus datos de contacto. '
              'Esto no se puede deshacer. Los registros de viajes y pagos se guardan '
              'sin tu nombre, como lo exige la ley.',
              style: TextStyle(fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 14),
            TextField(
              key: const Key('campo_eliminar_cuenta'),
              controller: _texto,
              enabled: !_borrando,
              textCapitalization: TextCapitalization.characters,
              decoration: decoracionCampoAuth(label: 'Escribe $_palabra', icono: Icons.warning_amber_rounded),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              AvisoErrorAuth(mensaje: _error!),
            ],
          ],
        ),
        textoPrincipal: 'Eliminar cuenta',
        colorPrincipal: ColoresApp.rojo,
        cargando: _borrando,
        onPrincipal: _eliminar,
        textoSecundario: 'Cancelar',
        onSecundario: () => Navigator.pop(context, false),
      ),
    );
  }
}
