import 'package:flutter/material.dart';

import '../../../services/api/empresa_service.dart';
import '../../../widgets/error_carga.dart' show mensajeDeError;
import '../../shared/ui_compartida.dart';
import '../../user/auth_estilos.dart';

/// Pide el código de la empresa y llama a POST /api/empresas/unirse. Devuelve
/// `true` si se unió. Con un código inválido deja el diálogo abierto con el
/// mensaje del servidor.
Future<bool> mostrarUnirseEmpresa(BuildContext context) async {
  final r = await showDialog<bool>(context: context, builder: (_) => const _DialogoUnirse());
  return r == true;
}

class _DialogoUnirse extends StatefulWidget {
  const _DialogoUnirse();

  @override
  State<_DialogoUnirse> createState() => _DialogoUnirseState();
}

class _DialogoUnirseState extends State<_DialogoUnirse> {
  final _codigo = TextEditingController();
  bool _enviando = false;
  String? _error;

  @override
  void dispose() {
    _codigo.dispose();
    super.dispose();
  }

  Future<void> _unirse() async {
    final c = _codigo.text.trim().toUpperCase();
    if (c.isEmpty) {
      setState(() => _error = 'Escribe el código que te dio tu empresa');
      return;
    }
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      await EmpresaService.unirse(c);
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

  @override
  Widget build(BuildContext context) {
    return DialogoApp(
      icono: Icons.group_add_outlined,
      titulo: 'Unirme a una empresa',
      cuerpo: 'Escribe el código que te dio el dueño de la empresa.',
      desplazable: true,
      contenido: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
          controller: _codigo,
          enabled: !_enviando,
          textCapitalization: TextCapitalization.characters,
          decoration: decoracionCampoAuth(label: 'Código de la empresa', icono: Icons.vpn_key_outlined),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          CajaAviso(texto: _error!, icono: Icons.error_outline, color: ColoresApp.rojo, fondo: ColoresApp.rojoFondo),
        ],
      ]),
      textoPrincipal: 'Unirme',
      cargando: _enviando,
      onPrincipal: _unirse,
      textoSecundario: 'Cancelar',
    );
  }
}
