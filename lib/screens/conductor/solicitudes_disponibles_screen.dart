import 'package:flutter/material.dart';

import '../../services/solicitudes_disponibles_service.dart';
import 'solicitudes_disponibles_section.dart';
import '../shared/ui_compartida.dart';

/// Pantalla propia con todas las solicitudes disponibles (la del inicio
/// muestra sólo las primeras). Tirar hacia abajo vuelve a consultar.
class SolicitudesDisponiblesScreen extends StatelessWidget {
  const SolicitudesDisponiblesScreen({super.key});


  @override
  Widget build(BuildContext context) {
    final servicio = SolicitudesDisponiblesService.instance;
    return Scaffold(
      backgroundColor: ColoresApp.fondo,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: ColoresApp.textoOscuro,
        elevation: 0,
        title: const Text('Solicitudes disponibles', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
      ),
      body: RefreshIndicator(
        onRefresh: servicio.sincronizar,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
          child: SolicitudesDisponiblesSection(
            online: servicio.activo,
            mostrarEncabezado: false,
          ),
        ),
      ),
    );
  }
}
