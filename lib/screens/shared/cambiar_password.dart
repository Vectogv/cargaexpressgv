import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../services/api/http_client.dart' show ApiException;
import '../user/auth_estilos.dart';
import 'soporte_contacto.dart';

/// Diálogo para cambiar la contraseña (PUT /api/users/password), compartido
/// entre el cliente y el conductor. Mismo patrón de "Editar perfil" en
/// `cliente/perfil_screen.dart`: error inline sin cerrar, PopScope mientras
/// guarda y los campos de `auth_estilos.dart`.
Future<void> mostrarDialogoCambiarPassword(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _DialogoCambiarPassword(),
  );
  if (ok == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contraseña actualizada')));
  }
}

class _DialogoCambiarPassword extends StatefulWidget {
  const _DialogoCambiarPassword();

  @override
  State<_DialogoCambiarPassword> createState() => _DialogoCambiarPasswordState();
}

class _DialogoCambiarPasswordState extends State<_DialogoCambiarPassword> {
  static const int _minimoNueva = 8;

  final _actual = TextEditingController();
  final _nueva = TextEditingController();
  final _confirmar = TextEditingController();
  String? _error;
  bool _guardando = false;

  @override
  void dispose() {
    _actual.dispose();
    _nueva.dispose();
    _confirmar.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_nueva.text.length < _minimoNueva) {
      setState(() => _error = 'La nueva contraseña debe tener al menos $_minimoNueva caracteres');
      return;
    }
    if (_nueva.text != _confirmar.text) {
      setState(() => _error = 'Las contraseñas nuevas no coinciden');
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await ApiClient.instance.changePassword(_actual.text, _nueva.text);
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

  Widget _campo(Key key, TextEditingController c, String label) {
    return TextField(
      key: key,
      controller: c,
      obscureText: true,
      enabled: !_guardando,
      decoration: decoracionCampoAuth(label: label, icono: Icons.lock_outline_rounded),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_guardando,
      child: AlertDialog(
        title: const Text('Cambiar contraseña'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _campo(const Key('campo_password_actual'), _actual, 'Contraseña actual'),
              const SizedBox(height: 14),
              _campo(const Key('campo_password_nueva'), _nueva, 'Nueva contraseña'),
              const SizedBox(height: 14),
              _campo(const Key('campo_password_confirmar'), _confirmar, 'Confirmar contraseña'),
              if (_error != null) ...[
                const SizedBox(height: 14),
                AvisoErrorAuth(mensaje: _error!),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _guardando ? null : () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: _guardando ? null : _guardar,
            child: Text(_guardando ? 'Guardando…' : 'Guardar'),
          ),
        ],
      ),
    );
  }
}

/// Hoja de "¿Olvidaste tu contraseña?" en el login: el cambio lo hace soporte,
/// no la app. `ContactoSoporteSection` ya consulta GET /support/help sin
/// sesión (endpoint público), así que sirve tal cual antes de iniciar sesión.
Future<void> mostrarAyudaPasswordOlvidada(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      maxChildSize: 0.9,
      builder: (_, controller) => SingleChildScrollView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('¿Olvidaste tu contraseña?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AuthColores.texto)),
            SizedBox(height: 8),
            Text(
              'Por seguridad, el cambio lo hace nuestro equipo de soporte. Escríbenos y te ayudamos.',
              style: TextStyle(fontSize: 14, color: AuthColores.gris, height: 1.4),
            ),
            SizedBox(height: 20),
            ContactoSoporteSection(),
          ],
        ),
      ),
    ),
  );
}
